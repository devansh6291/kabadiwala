"""Kabadiwala Connect - dataset ingestion & crop pipeline.

Builds two item lists from Roboflow YOLO exports plus TrashNet:

    p1_items - binary task: e-waste (label 1) vs non-e-waste (label 0)
    p2_items - hierarchical task: category + subCategory, e-waste only

Both are written to CSV manifests under WORK_DIR so downstream notebooks
import a file rather than re-running this script.

Key guarantees:
  * Splits are deterministic, stratified, and duplicate-aware. The same
    image (or a re-encode of it) can never land in two different splits.
  * Categories are emitted in Data Dictionary vocabulary - "PCB", "Cables",
    "Battery", "Motor", "CRT", "MixedPlastics", "OtherEwaste" - so no
    translation layer is needed downstream.
  * Source class names that map to nothing are dropped and reported, not
    silently bucketed into OtherEwaste.

Usage:
    export ROBOFLOW_API_KEY=...
    python dataset_pipeline.py
"""

from __future__ import annotations

import csv
import hashlib
import json
import os
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Callable, Dict, Iterable, Iterator, List, Optional, Tuple

import yaml
from PIL import Image, UnidentifiedImageError

try:
    from tqdm.auto import tqdm
except ImportError:  # tqdm is a nicety, not a dependency
    def tqdm(iterable=None, **kwargs):
        return iterable if iterable is not None else []

# ==========================================
# 1. Configuration & Path Setup
# ==========================================
SEED = 42

WORK_DIR = Path(os.environ.get("KC_WORK_DIR", "./kabadiwala_work"))
RAW_DIR = WORK_DIR / "raw"
CROP_DIR = WORK_DIR / "crops"
CKPT_DIR = WORK_DIR / "checkpoints"
CACHE_DIR = WORK_DIR / "cache"
MANIFEST_DIR = WORK_DIR / "manifests"
TRASHNET_IMAGES = RAW_DIR / "dataset-resized"

for _d in (RAW_DIR, CROP_DIR, CKPT_DIR, CACHE_DIR, MANIFEST_DIR):
    _d.mkdir(parents=True, exist_ok=True)

SPLIT_DIRS = {"train": "train", "val": "val", "valid": "val", "test": "test"}
IMG_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

# Tunables
MIN_CROP_SIDE = 64          # below this, a 224px model is mostly upsampling
CROP_MARGIN = 0.08          # context padding around each box
TRAIN_RATIO, VAL_RATIO = 0.80, 0.10
DROP_NEAR_DUPLICATES = True  # perceptual-hash dedup across sources
INCLUDE_EXTRA_NEGATIVES = True  # use all non-plastic TrashNet classes as label 0

# NEVER commit a key here. The previous default in this file was a live
# credential and must be rotated in the Roboflow console.
ROBOFLOW_API_KEY = os.environ.get("ROBOFLOW_API_KEY", "")

ROBOFLOW_SOURCES: List[Dict[str, Any]] = [
    {"workspace": "student-esos5", "project": "e-waste-classifications", "version": 5},
    {"workspace": "student-esos5", "project": "e-waste-u7rro", "version": 3},
    {"workspace": "jensen", "project": "e-waste-detection-g7vf3", "version": 1},
    {"workspace": "work-9dvgk", "project": "ewaste-efxwy", "version": 1},
    {"workspace": "vision-experiments-fprmb", "project": "electronic-waste-object-detection-system", "version": 1},
]

# TrashNet is not on Roboflow. Download `dataset-resized.zip` from
# https://github.com/garythung/trashnet and unzip into RAW_DIR so that
# RAW_DIR/dataset-resized/{cardboard,glass,metal,paper,plastic,trash}/ exists.
TRASHNET_EWASTE_NEGATIVES = {"cardboard", "glass", "metal", "paper", "trash"}

DOWNLOAD_SENTINEL = ".download_complete"


# ==========================================
# 2. Roboflow downloader
# ==========================================
def download_roboflow_datasets(sources: Optional[List[Dict[str, Any]]] = None) -> None:
    """Download any missing datasets. One failure never blocks the rest.

    A directory only counts as present if it holds a DOWNLOAD_SENTINEL file,
    so a run interrupted mid-download is retried instead of being treated as
    complete forever.
    """
    sources = sources or ROBOFLOW_SOURCES
    if not ROBOFLOW_API_KEY:
        print("[warn] ROBOFLOW_API_KEY is unset - skipping downloads. "
              "Existing folders in RAW_DIR will still be processed.")
        return

    try:
        from roboflow import Roboflow
    except ImportError:
        print("[warn] `pip install roboflow` to enable automatic downloads.")
        return

    rf = Roboflow(api_key=ROBOFLOW_API_KEY)
    for src in sources:
        target_dir = RAW_DIR / f"{src['project']}_v{src['version']}"
        if (target_dir / DOWNLOAD_SENTINEL).exists():
            print(f"  [skip] already downloaded: {target_dir.name}")
            continue
        if target_dir.exists():
            print(f"  [retry] incomplete download found, re-fetching: {target_dir.name}")
        try:
            print(f"  [get ] {src['project']} v{src['version']} ...")
            project = rf.workspace(src["workspace"]).project(src["project"])
            project.version(src["version"]).download("yolov8", location=str(target_dir))
            (target_dir / DOWNLOAD_SENTINEL).write_text("ok\n")
        except Exception as exc:  # one bad project must not skip the other four
            print(f"  [fail] {src['project']} v{src['version']}: {exc}")


# ==========================================
# 3. Source label -> Data Dictionary category
# ==========================================
# Ordered rules: the FIRST match wins, so specific labels must precede
# generic ones. "phone charger" has to hit Cables before MobilePhone, and
# "motherboard" has to hit the Motherboard rule before the generic board
# rule. Matching is on whole tokens, so "scanner" no longer matches "can"
# and "canister" no longer becomes ScrapMetal.
CATEGORY_RULES: List[Tuple[Tuple[str, ...], str, Optional[str]]] = [
    (("charger", "cable", "cables", "wire", "wires", "wiring", "cord",
      "adapter", "adaptor", "plug", "usb", "connector"), "Cables", "Cable"),
    (("battery", "batteries", "lithium", "accumulator", "powerbank"), "Battery", None),
    (("motor", "fan", "compressor", "dynamo", "pump", "rotor"), "Motor", None),
    (("crt", "cathode"), "CRT", None),
    (("motherboard", "mainboard", "mobo", "logicboard"), "PCB", "Motherboard"),
    (("pcb", "pcbs", "circuit", "circuitboard", "semiconductor", "chipset",
      "microchip", "board", "boards"), "PCB", None),
    (("laptop", "laptops", "notebook", "macbook"), "OtherEwaste", "Laptop"),
    (("keyboard", "keyboards"), "OtherEwaste", "Keyboard"),
    (("mouse", "mice"), "OtherEwaste", "Mouse"),
    (("phone", "phones", "smartphone", "mobile", "cellphone", "handset"), "OtherEwaste", "MobilePhone"),
    (("plastic", "plastics", "bottle", "bottles", "polymer", "pet"), "MixedPlastics", None),
    (("metal", "metals", "aluminium", "aluminum", "copper", "steel", "iron",
      "brass", "scrap", "can", "cans"), "OtherEwaste", "ScrapMetal"),
    (("monitor", "screen", "display", "tv", "television", "printer", "scanner",
      "router", "modem", "camera", "speaker", "headphone", "earphone", "remote",
      "calculator", "microwave", "refrigerator", "fridge", "washing", "console",
      "tablet", "player", "drive", "hdd", "ssd", "ram", "cpu", "processor",
      "smartwatch", "bulb", "lamp"), "OtherEwaste", None),
    (("ewaste", "waste", "electronic", "electronics", "electrical",
      "appliance", "device"), "OtherEwaste", None),
]

# Placeholder / annotation-artefact classes that carry no material meaning.
JUNK_LABELS = {
    "", "-", "_", "0", "1", "2", "none", "null", "na", "nan", "object", "objects",
    "item", "items", "class", "classes", "background", "bg", "unknown", "other",
    "person", "people", "hand", "hands", "face", "undefined", "label", "roi", "box",
}

UNMATCHED_CLASSES: Counter = Counter()
MATCHED_CLASSES: Counter = Counter()

_TOKEN_RE = re.compile(r"[a-z0-9]+")


def _tokenize(cls_name: str) -> List[str]:
    return _TOKEN_RE.findall(cls_name.lower().replace("-", " ").replace("_", " "))


def classify_source_label(cls_name: str) -> Optional[Tuple[str, Optional[str]]]:
    """Map a raw dataset class name to (category, subCategory).

    Returns None for junk and for anything the rules do not cover - the
    caller drops those crops instead of dumping them into OtherEwaste,
    which is what previously poisoned the OtherEwaste class.
    """
    normalized = " ".join(_tokenize(cls_name))
    if normalized in JUNK_LABELS or not normalized:
        UNMATCHED_CLASSES[cls_name] += 1
        return None

    tokens = set(normalized.split())
    for keywords, category, sub_category in CATEGORY_RULES:
        if tokens & set(keywords):
            MATCHED_CLASSES[f"{cls_name} -> {category}/{sub_category}"] += 1
            return category, sub_category

    UNMATCHED_CLASSES[cls_name] += 1
    return None


def map_class_to_category(cls_name: str) -> Optional[str]:
    """Backwards-compatible wrapper: category only, None when unmapped."""
    hit = classify_source_label(cls_name)
    return hit[0] if hit else None


def report_label_coverage() -> None:
    """Print what the rules matched and, more importantly, what they didn't."""
    print("\n--- Source label coverage ---")
    if MATCHED_CLASSES:
        print(f"matched {len(MATCHED_CLASSES)} distinct labels:")
        for label, count in MATCHED_CLASSES.most_common():
            print(f"    {count:7,d}  {label}")
    if UNMATCHED_CLASSES:
        print(f"DROPPED {len(UNMATCHED_CLASSES)} unmapped labels "
              f"({sum(UNMATCHED_CLASSES.values()):,} annotations):")
        for label, count in UNMATCHED_CLASSES.most_common(30):
            print(f"    {count:7,d}  {label!r}")
        print("  -> add a rule to CATEGORY_RULES for anything here that matters.")
    else:
        print("every source label was mapped.")


# ==========================================
# 4. Image hashing & deduplication
# ==========================================
class HashCache:
    """Path -> (sha256, dhash) cache, invalidated by size+mtime."""

    def __init__(self, path: Path):
        self.path = path
        self.data: Dict[str, List[Any]] = {}
        if path.exists():
            try:
                self.data = json.loads(path.read_text())
            except (json.JSONDecodeError, OSError):
                self.data = {}
        self.dirty = False

    @staticmethod
    def _key(p: Path) -> str:
        st = p.stat()
        return f"{p}|{st.st_size}|{st.st_mtime_ns}"

    def get(self, p: Path) -> Optional[List[Any]]:
        return self.data.get(self._key(p))

    def put(self, p: Path, value: List[Any]) -> None:
        self.data[self._key(p)] = value
        self.dirty = True

    def save(self) -> None:
        if self.dirty:
            self.path.write_text(json.dumps(self.data))
            self.dirty = False


def sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(chunk), b""):
            h.update(block)
    return h.hexdigest()


def dhash_image(path: Path, size: int = 8) -> Optional[str]:
    """64-bit difference hash. None for near-blank images, where dHash
    collides on everything and would merge unrelated files."""
    try:
        with Image.open(path) as im:
            gray = im.convert("L").resize((size + 1, size), Image.LANCZOS)
    except (OSError, UnidentifiedImageError):
        return None

    pixels = list(gray.tobytes())  # mode "L": one byte per pixel, row-major
    rows = [pixels[r * (size + 1):(r + 1) * (size + 1)] for r in range(size)]
    flat = [px for row in rows for px in row]
    mean = sum(flat) / len(flat)
    variance = sum((px - mean) ** 2 for px in flat) / len(flat)
    if variance < 25.0:  # flat/near-blank crop
        return None

    bits = "".join(
        "1" if row[c] > row[c + 1] else "0" for row in rows for c in range(size)
    )
    return f"{int(bits, 2):016x}"


def deduplicate(items: List[Dict[str, Any]], drop_near: bool = DROP_NEAR_DUPLICATES
                ) -> List[Dict[str, Any]]:
    """Attach a `group_key` to every item and drop redundant copies.

    Exact duplicates (identical bytes) are always dropped. Perceptual
    duplicates - the same photo re-encoded, which is how the same public
    dataset ends up inside three different Roboflow forks - are dropped when
    `drop_near` is set. The surviving `group_key` is what the splitter keys
    on, so even a duplicate that slips through cannot straddle two splits.
    """
    cache = HashCache(CACHE_DIR / "image_hashes.json")
    seen: Dict[str, str] = {}
    kept: List[Dict[str, Any]] = []
    dropped_exact = dropped_near = 0

    for item in tqdm(items, desc="Deduplicating", leave=False):
        path = Path(item["image_path"])
        try:
            cached = cache.get(path)
            if cached is None:
                cached = [sha256_file(path), dhash_image(path)]
                cache.put(path, cached)
        except OSError:
            continue  # vanished mid-run
        sha, dhash = cached

        group_key = dhash if (drop_near and dhash) else sha
        if group_key in seen and seen[group_key] != str(path):
            if sha == seen.get(f"sha:{group_key}"):
                dropped_exact += 1
            else:
                dropped_near += 1
            continue
        seen[group_key] = str(path)
        seen[f"sha:{group_key}"] = sha
        kept.append({**item, "group_key": group_key})

    cache.save()
    if dropped_exact or dropped_near:
        print(f"  deduplicated: {dropped_exact:,} exact + {dropped_near:,} perceptual "
              f"duplicates removed ({len(kept):,} kept of {len(items):,})")
    return kept


# ==========================================
# 5. Deterministic, stratified splitting
# ==========================================
def assign_splits(
    items: List[Dict[str, Any]],
    train_ratio: float = TRAIN_RATIO,
    val_ratio: float = VAL_RATIO,
    seed: int = SEED,
) -> None:
    """Assign train/val/test in place. Deterministic and stratified.

    Behaviour change from the original `finalize_splits`: source-provided
    splits are IGNORED and every item is reassigned. That is deliberate.
    The old code only touched items with no split, and since every item
    arrived pre-stamped from its export directory, it never reassigned
    anything - all TrashNet negatives stayed in `train`, leaving the binary
    val/test sets with zero negatives.

    Ordering comes from a hash of (seed, group_key), so the result is stable
    across runs and machines without depending on `random`'s global state,
    and duplicate groups always move together.
    """
    groups: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for item in items:
        groups[item.get("group_key") or item["image_path"]].append(item)

    # Stratify on the label the model actually has to separate.
    strata: Dict[str, List[str]] = defaultdict(list)
    for key, members in groups.items():
        head = members[0]
        if head.get("category"):
            # Stratify on the finest label available. Using category alone
            # let a rare subCategory (e.g. MobilePhone inside OtherEwaste)
            # miss val/test entirely.
            stratum = f"{head['category']}/{head.get('subCategory') or '-'}"
        else:
            stratum = f"label={head.get('label')}"
        strata[stratum].append(key)

    for stratum, keys in sorted(strata.items()):
        keys.sort(key=lambda k: hashlib.sha256(f"{seed}:{k}".encode()).hexdigest())
        n = len(keys)
        n_train = int(round(n * train_ratio))
        n_val = int(round(n * val_ratio))
        if n >= 3:  # never let a stratum end up with an empty val or test
            n_train = min(n_train, n - 2)
            n_val = max(1, min(n_val, n - n_train - 1))

        for i, key in enumerate(keys):
            split = "train" if i < n_train else ("val" if i < n_train + n_val else "test")
            for item in groups[key]:
                item["split"] = split


def finalize_splits(items: List[Dict[str, Any]], train_ratio: float = TRAIN_RATIO,
                    val_ratio: float = VAL_RATIO) -> None:
    """Kept for import compatibility; delegates to assign_splits."""
    assign_splits(items, train_ratio=train_ratio, val_ratio=val_ratio)


# ==========================================
# 6. Readers
# ==========================================
def iter_images(directory: Path) -> Iterator[Path]:
    if not directory.is_dir():
        return
    for path in sorted(directory.iterdir()):
        if path.suffix.lower() in IMG_EXTS:
            yield path


def gather_yolo_images(export_dir: Path) -> List[Dict[str, Any]]:
    """Whole-frame image index for a YOLO export.

    Retained for inspection only. Pipeline 1 no longer uses this: feeding it
    whole frames as positives and studio-shot TrashNet as negatives let the
    classifier separate the two on background alone.
    """
    items = []
    for split_dir in SPLIT_DIRS:
        for img_path in iter_images(export_dir / split_dir / "images"):
            items.append({"image_path": str(img_path), "source": export_dir.name})
    return items


def load_yolo_names(export_dir: Path) -> Optional[List[str]]:
    data_yaml = export_dir / "data.yaml"
    if not data_yaml.exists():
        print(f"  [skip] no data.yaml in {export_dir.name}")
        return None
    try:
        names = yaml.safe_load(data_yaml.read_text(encoding="utf-8"))["names"]
    except (yaml.YAMLError, KeyError, OSError) as exc:
        print(f"  [skip] unreadable data.yaml in {export_dir.name}: {exc}")
        return None
    if isinstance(names, dict):
        names = [names[k] for k in sorted(names)]
    return list(names)


def crop_yolo_export(
    export_dir: Path,
    out_dir: Path = CROP_DIR,
    class_to_category: Callable[[str], Optional[Tuple[str, Optional[str]]]] = classify_source_label,
    min_side: int = MIN_CROP_SIDE,
    margin: float = CROP_MARGIN,
) -> List[Dict[str, Any]]:
    """Crop every mapped bounding box out of a YOLO export.

    Crops are written to out_dir/<source>/<category>/ - NOT under a split
    directory. Splits live in the manifest only, so re-splitting never
    requires re-cropping, and a stale split can't be inferred from a path.
    """
    export_dir, out_dir = Path(export_dir), Path(out_dir)
    names = load_yolo_names(export_dir)
    if names is None:
        return []

    items: List[Dict[str, Any]] = []
    bad_labels = bad_images = too_small = unmapped = 0

    for split_dir in SPLIT_DIRS:
        img_dir = export_dir / split_dir / "images"
        lbl_dir = export_dir / split_dir / "labels"
        if not img_dir.is_dir():
            continue

        for img_path in tqdm(list(iter_images(img_dir)),
                             desc=f"  cropping {export_dir.name}/{split_dir}", leave=False):
            lbl_path = lbl_dir / f"{img_path.stem}.txt"
            if not lbl_path.exists():
                continue
            try:
                lines = [ln.strip() for ln in lbl_path.read_text().splitlines() if ln.strip()]
            except OSError:
                bad_labels += 1
                continue
            if not lines:
                continue

            try:
                with Image.open(img_path) as im:
                    image = im.convert("RGB")
            except (OSError, UnidentifiedImageError):
                bad_images += 1  # a corrupt jpeg must not kill a multi-hour run
                continue
            width, height = image.size

            for j, line in enumerate(lines):
                parts = line.split()
                if len(parts) < 5:
                    bad_labels += 1
                    continue
                try:
                    class_idx = int(float(parts[0]))
                    coords = [float(v) for v in parts[1:]]
                except ValueError:
                    bad_labels += 1
                    continue
                if not 0 <= class_idx < len(names):
                    bad_labels += 1
                    continue

                hit = class_to_category(names[class_idx])
                if hit is None:
                    unmapped += 1
                    continue
                category, sub_category = hit

                if len(coords) == 4:
                    cx, cy, w, h = coords
                    x0, y0, x1, y1 = cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2
                elif len(coords) >= 6 and len(coords) % 2 == 0:
                    xs, ys = coords[0::2], coords[1::2]
                    x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
                else:
                    bad_labels += 1
                    continue

                mx, my = (x1 - x0) * margin, (y1 - y0) * margin
                box = (
                    max(0, int((x0 - mx) * width)),
                    max(0, int((y0 - my) * height)),
                    min(width, int((x1 + mx) * width)),
                    min(height, int((y1 + my) * height)),
                )
                crop_w, crop_h = box[2] - box[0], box[3] - box[1]
                if crop_w < min_side or crop_h < min_side:
                    too_small += 1
                    continue

                dest = out_dir / export_dir.name / category
                dest.mkdir(parents=True, exist_ok=True)
                out_path = dest / f"{img_path.stem}_{j}.jpg"
                if not out_path.exists():
                    try:
                        image.crop(box).save(out_path, quality=90)
                    except OSError:
                        bad_images += 1
                        continue

                items.append({
                    "image_path": str(out_path),
                    "category": category,
                    "subCategory": sub_category,
                    "source": export_dir.name,
                    "source_class": names[class_idx],
                    "crop_w": crop_w,
                    "crop_h": crop_h,
                })

    print(f"  {export_dir.name}: {len(items):,} crops "
          f"(dropped {unmapped:,} unmapped, {too_small:,} under {min_side}px, "
          f"{bad_labels:,} bad labels, {bad_images:,} bad images)")
    return items


def index_class_folders(
    base_dir: Path,
    mapper_fn: Callable[[str], Optional[str]],
) -> List[Dict[str, Any]]:
    """Index an ImageFolder-style dataset. No split is assigned here.

    The original version hardcoded `"split": "train"` on every item, which -
    combined with the old finalize_splits - is why no negative ever reached
    the validation set.
    """
    items: List[Dict[str, Any]] = []
    if not base_dir.is_dir():
        return items
    for folder in sorted(base_dir.iterdir()):
        if not folder.is_dir():
            continue
        category = mapper_fn(folder.name)
        if category is None:
            continue
        for img_path in iter_images(folder):
            items.append({
                "image_path": str(img_path),
                "category": category,
                "source": base_dir.name,
                "source_class": folder.name,
            })
    return items


def center_crop_images(
    items: List[Dict[str, Any]],
    out_dir: Path = CROP_DIR,
    fraction: float = 0.8,
    min_side: int = MIN_CROP_SIDE,
) -> List[Dict[str, Any]]:
    """Square centre-crop whole-frame images so they match object crops.

    TrashNet is studio shots on white; the Roboflow positives are tight
    object crops. Without this, framing alone separates the two classes and
    Pipeline 1 learns the dataset rather than the material.
    """
    out: List[Dict[str, Any]] = []
    for item in tqdm(items, desc="  centre-cropping", leave=False):
        src = Path(item["image_path"])
        try:
            with Image.open(src) as im:
                image = im.convert("RGB")
        except (OSError, UnidentifiedImageError):
            continue

        side = int(min(image.size) * fraction)
        if side < min_side:
            continue
        left = (image.width - side) // 2
        top = (image.height - side) // 2

        dest = out_dir / item["source"] / (item.get("category") or item["source_class"])
        dest.mkdir(parents=True, exist_ok=True)
        out_path = dest / f"{src.stem}_cc.jpg"
        if not out_path.exists():
            try:
                image.crop((left, top, left + side, top + side)).save(out_path, quality=90)
            except OSError:
                continue

        out.append({**item, "image_path": str(out_path), "crop_w": side, "crop_h": side})
    return out


# ==========================================
# 7. Manifests
# ==========================================
MANIFEST_FIELDS = [
    "image_path", "split", "label", "category", "subCategory",
    "source", "source_class", "crop_w", "crop_h", "group_key",
]


def write_manifest(items: List[Dict[str, Any]], path: Path) -> None:
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=MANIFEST_FIELDS, extrasaction="ignore")
        writer.writeheader()
        for item in items:
            writer.writerow({k: item.get(k, "") for k in MANIFEST_FIELDS})
    print(f"  wrote {len(items):,} rows -> {path}")


def read_manifest(path: Path) -> List[Dict[str, Any]]:
    """Load a manifest back. Downstream code should start here, not by
    re-running the whole ingest."""
    with open(path, newline="", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    for row in rows:
        if row.get("label") not in ("", None):
            row["label"] = int(row["label"])
        for key in ("crop_w", "crop_h"):
            row[key] = int(row[key]) if row.get(key) else None
        row["subCategory"] = row.get("subCategory") or None
    return rows


def export_imagefolder(items: List[Dict[str, Any]], dest_root: Path,
                       label_key: str = "category") -> Path:
    """Materialise split/class/ directories for tools that demand that layout
    (ultralytics YOLO-cls). Symlinks where possible, copies on Windows."""
    import shutil

    dest_root.mkdir(parents=True, exist_ok=True)
    for item in items:
        label = item.get(label_key)
        if not label or not item.get("split"):
            continue
        dest = dest_root / item["split"] / str(label)
        dest.mkdir(parents=True, exist_ok=True)
        target = dest / Path(item["image_path"]).name
        if target.exists():
            continue
        try:
            target.symlink_to(Path(item["image_path"]).resolve())
        except (OSError, NotImplementedError):
            shutil.copy2(item["image_path"], target)
    print(f"  ImageFolder tree -> {dest_root}")
    return dest_root


# ==========================================
# 8. Build
# ==========================================
def build_items(run_download: bool = True) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """Build and persist p1_items / p2_items.

    Importable, unlike the old `__main__` block - downstream notebooks can
    call this directly, or read the manifests it writes.
    """
    if run_download:
        print("--- Downloading Roboflow sources ---")
        download_roboflow_datasets()

    print("\n--- Cropping YOLO exports ---")
    ewaste_crops: List[Dict[str, Any]] = []
    for src in ROBOFLOW_SOURCES:
        export = RAW_DIR / f"{src['project']}_v{src['version']}"
        if not export.exists():
            print(f"  [missing] {export.resolve()}")
            continue
        ewaste_crops += crop_yolo_export(export)

    print("\n--- TrashNet ---")
    plastics: List[Dict[str, Any]] = []
    negatives: List[Dict[str, Any]] = []
    if TRASHNET_IMAGES.exists():
        plastics = center_crop_images(index_class_folders(
            TRASHNET_IMAGES, lambda n: "MixedPlastics" if n.lower() == "plastic" else None))
        print(f"  plastics: {len(plastics):,}")
        if INCLUDE_EXTRA_NEGATIVES:
            negatives = center_crop_images(index_class_folders(
                TRASHNET_IMAGES,
                lambda n: None if n.lower() not in TRASHNET_EWASTE_NEGATIVES else "NonEwaste"))
            print(f"  extra negatives (glass/metal/paper/cardboard/trash): {len(negatives):,}")
    else:
        print(f"  [missing] {TRASHNET_IMAGES.resolve()} - see TrashNet note at the top "
              "of this file. Without it Pipeline 1 has no negatives at all.")

    # --- Pipeline 1: binary, crops on BOTH sides ---------------------
    # `category` is carried through for stratification; "NonEwaste" is a
    # P1-only marker, not a Lot category, and never reaches p2_items.
    p1_items = (
        [{**it, "label": 1} for it in ewaste_crops if it["category"] != "MixedPlastics"]
        + [{**it, "label": 0} for it in plastics]
        + [{**it, "label": 0} for it in negatives]
    )

    # --- Pipeline 2: e-waste hierarchy only --------------------------
    p2_items = [it for it in ewaste_crops if it["category"] != "MixedPlastics"]

    print("\n--- Deduplicating ---")
    p1_items = deduplicate(p1_items)
    p2_items = deduplicate(p2_items)

    print("\n--- Assigning splits ---")
    assign_splits(p1_items)
    assign_splits(p2_items)

    print("\n--- Writing manifests ---")
    write_manifest(p1_items, MANIFEST_DIR / "p1_binary.csv")
    write_manifest(p2_items, MANIFEST_DIR / "p2_hierarchy.csv")
    return p1_items, p2_items


def summarize(items: List[Dict[str, Any]], name: str, key: str) -> None:
    print(f"\n{name}: {len(items):,} items")
    table: Dict[Any, Counter] = defaultdict(Counter)
    for item in items:
        table[item.get(key)][item.get("split", "?")] += 1
    header = f"  {'value':<16}" + "".join(f"{s:>8}" for s in ("train", "val", "test"))
    print(header)
    print("  " + "-" * (len(header) - 2))
    for value, counts in sorted(table.items(), key=lambda kv: -sum(kv[1].values())):
        row = "".join(f"{counts.get(s, 0):>8,d}" for s in ("train", "val", "test"))
        print(f"  {str(value):<16}{row}")
        if counts.get("val", 0) == 0 or counts.get("test", 0) == 0:
            print(f"      ^ WARNING: {value!r} is missing from val or test")


if __name__ == "__main__":
    p1_items, p2_items = build_items(run_download="--no-download" not in sys.argv)

    report_label_coverage()
    print("\n" + "=" * 58)
    print("SUMMARY")
    print("=" * 58)
    summarize(p1_items, "Pipeline 1 (binary)", "label")
    summarize(p2_items, "Pipeline 2 (hierarchy)", "category")
    summarize(p2_items, "Pipeline 2 (subCategory)", "subCategory")

    if not any(it["label"] == 0 for it in p1_items):
        print("\n*** Pipeline 1 has no negatives. Install TrashNet before training. ***")
