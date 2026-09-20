import os
import random
from collections import Counter
from pathlib import Path
from typing import Callable, Dict, List, Optional, Any

import yaml
from PIL import Image
from tqdm.auto import tqdm

# ==========================================
# 1. Configuration & Path Setup
# ==========================================
SEED = 42

# Local directory paths for Windows/Linux
WORK_DIR = Path("./kabadiwala_work")
RAW_DIR = WORK_DIR / "raw"
CROP_DIR = WORK_DIR / "crops"
CKPT_DIR = WORK_DIR / "checkpoints"
TRASHNET_IMAGES = RAW_DIR / "dataset-resized"

for _d in (RAW_DIR, CROP_DIR, CKPT_DIR):
    _d.mkdir(parents=True, exist_ok=True)

SPLIT_DIRS = {"train": "train", "val": "val", "valid": "val", "test": "test"}
IMG_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

# Put your Roboflow API key here (or pass via environment variable)
ROBOFLOW_API_KEY = os.environ.get("ROBOFLOW_API_KEY", "xdT3uTf4M3SK8aIjGJnU")

ROBOFLOW_SOURCES: List[Dict[str, Any]] = [
    {"workspace": "student-esos5", "project": "e-waste-classifications", "version": 5},
    {"workspace": "student-esos5", "project": "e-waste-u7rro", "version": 3},
    {"workspace": "jensen", "project": "e-waste-detection-g7vf3", "version": 1},
    {"workspace": "work-9dvgk", "project": "ewaste-efxwy", "version": 1},
    {"workspace": "vision-experiments-fprmb", "project": "electronic-waste-object-detection-system", "version": 1},
]

# ==========================================
# 2. Automated Roboflow Dataset Downloader
# ==========================================
def download_roboflow_datasets():
    """Downloads missing datasets from Roboflow using the API."""
    if ROBOFLOW_API_KEY in ["", "YOUR_ROBOFLOW_API_KEY_HERE"]:
        print("[Warning] No valid ROBOFLOW_API_KEY found. Skipping automatic download.")
        return

    try:
        from roboflow import Roboflow
        rf = Roboflow(api_key=ROBOFLOW_API_KEY)
        
        for src in ROBOFLOW_SOURCES:
            target_dir = RAW_DIR / f"{src['project']}_v{src['version']}"
            if not target_dir.exists():
                print(f"Downloading {src['project']} v{src['version']}...")
                project = rf.workspace(src["workspace"]).project(src["project"])
                dataset = project.version(src["version"]).download("yolov8", location=str(target_dir))
            else:
                print(f"Found existing dataset: {target_dir.name}")
    except Exception as e:
        print(f"[Error] Failed to download Roboflow datasets: {e}")

# ==========================================
# 3. Helper Functions
# ==========================================
def map_class_to_category(cls_name: str) -> Optional[str]:
    name = cls_name.lower().replace("-", " ").replace("_", " ")
    if any(k in name for k in ["circuit", "pcb", "motherboard", "semiconductor"]):
        return "CircuitBoard"
    if any(k in name for k in ["mobile", "phone", "smartphone", "cell"]):
        return "MobilePhone"
    if any(k in name for k in ["cable", "wire", "charger", "cord"]):
        return "CableWire"
    if any(k in name for k in ["plastic", "bottle", "container"]):
        return "MixedPlastics"
    if any(k in name for k in ["metal", "can", "aluminum", "copper"]):
        return "ScrapMetal"
    return "OtherEwaste"

def gather_yolo_images(export_dir: Path) -> List[Dict[str, Any]]:
    items = []
    for split_dir, split in SPLIT_DIRS.items():
        img_dir = export_dir / split_dir / "images"
        if not img_dir.is_dir():
            continue
        for img_path in sorted(img_dir.iterdir()):
            if img_path.suffix.lower() in IMG_EXTS:
                items.append({
                    "image_path": str(img_path),
                    "split": split,
                    "source": export_dir.name
                })
    return items

def index_class_folders(base_dir: Path, mapper_fn: Callable[[str], Optional[str]]) -> List[Dict[str, Any]]:
    items = []
    if not base_dir.is_dir():
        return items
    for folder in base_dir.iterdir():
        if folder.is_dir():
            cat = mapper_fn(folder.name)
            if cat:
                for img_path in folder.iterdir():
                    if img_path.suffix.lower() in IMG_EXTS:
                        items.append({
                            "image_path": str(img_path),
                            "category": cat,
                            "split": "train",
                            "source": base_dir.name
                        })
    return items

def finalize_splits(items: List[Dict[str, Any]], train_ratio: float = 0.8, val_ratio: float = 0.1) -> None:
    unassigned = [it for it in items if "split" not in it or it["split"] not in ("train", "val", "test")]
    if not unassigned:
        return
    
    random.shuffle(unassigned)
    n = len(unassigned)
    n_train = int(n * train_ratio)
    n_val = int(n * val_ratio)

    for i, item in enumerate(unassigned):
        if i < n_train:
            item["split"] = "train"
        elif i < n_train + n_val:
            item["split"] = "val"
        else:
            item["split"] = "test"

def crop_yolo_export(
    export_dir: Path,
    out_dir: Path,
    class_to_category: Callable[[str], Optional[str]] = map_class_to_category,
    min_side: int = 48,
    margin: float = 0.08,
) -> List[Dict[str, Any]]:
    export_dir, out_dir = Path(export_dir), Path(out_dir)
    data_yaml = export_dir / "data.yaml"
    if not data_yaml.exists():
        return []

    with open(data_yaml, "r", encoding="utf-8") as fh:
        names = yaml.safe_load(fh)["names"]
    if isinstance(names, dict):
        names = [names[k] for k in sorted(names)]

    items: List[Dict[str, Any]] = []

    for split_dir, split in SPLIT_DIRS.items():
        img_dir = export_dir / split_dir / "images"
        lbl_dir = export_dir / split_dir / "labels"
        if not img_dir.is_dir():
            continue

        img_files = [p for p in sorted(img_dir.iterdir()) if p.suffix.lower() in IMG_EXTS]
        for img_path in tqdm(img_files, desc=f"Cropping {export_dir.name} ({split})", leave=False):
            lbl_path = lbl_dir / f"{img_path.stem}.txt"
            if not lbl_path.exists():
                continue

            lines = [line.strip() for line in lbl_path.read_text().splitlines() if line.strip()]
            if not lines:
                continue

            with Image.open(img_path) as im:
                image = im.convert("RGB")
            width, height = image.size

            for j, line in enumerate(lines):
                parts = line.split()
                if len(parts) < 5:
                    continue
                
                cls_name = names[int(float(parts[0]))]
                category = class_to_category(cls_name)
                if category is None:
                    continue

                coords = [float(v) for v in parts[1:]]
                if len(coords) == 4:
                    cx, cy, w, h = coords
                    x0, y0, x1, y1 = cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2
                else:
                    xs, ys = coords[0::2], coords[1::2]
                    x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)

                mx, my = (x1 - x0) * margin, (y1 - y0) * margin
                box = (
                    max(0, int((x0 - mx) * width)),
                    max(0, int((y0 - my) * height)),
                    min(width, int((x1 + mx) * width)),
                    min(height, int((y1 + my) * height)),
                )
                
                if box[2] - box[0] < min_side or box[3] - box[1] < min_side:
                    continue

                dest = out_dir / split / category
                dest.mkdir(parents=True, exist_ok=True)
                out_path = dest / f"{export_dir.name}_{img_path.stem}_{j}.jpg"
                
                if not out_path.exists():
                    image.crop(box).save(out_path, quality=90)

                items.append({
                    "image_path": str(out_path),
                    "category": category,
                    "split": split,
                    "source": export_dir.name
                })

    return items

# ==========================================
# 4. Pipeline Execution
# ==========================================
if __name__ == "__main__":
    # Attempt automatic download
    download_roboflow_datasets()

    p1_items: List[Dict[str, Any]] = []
    p2_items: List[Dict[str, Any]] = []

    rf_exports = [RAW_DIR / f"{s['project']}_v{s['version']}" for s in ROBOFLOW_SOURCES]

    for export in rf_exports:
        if export.exists():
            print(f"Processing dataset: {export.name}")
            p1_items += [{**it, "label": 1} for it in gather_yolo_images(export)]
            p2_items += crop_yolo_export(export, CROP_DIR)
        else:
            print(f"[Missing] Directory not found: {export.resolve()}")

    if TRASHNET_IMAGES.exists():
        print(f"Processing TrashNet plastics from: {TRASHNET_IMAGES.name}")
        plastics = index_class_folders(
            TRASHNET_IMAGES, lambda n: "MixedPlastics" if n == "plastic" else None
        )
        for it in plastics:
            p1_items.append({**it, "label": 0})
            p2_items.append(it)
    else:
        print(f"[Missing] TrashNet folder not found: {TRASHNET_IMAGES.resolve()}")

    finalize_splits(p1_items)
    finalize_splits(p2_items)

    print("\n--- Summary ---")
    print(f"Pipeline 1 items: {len(p1_items)}")
    print(f"Pipeline 2 items: {len(p2_items)}")