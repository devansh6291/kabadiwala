#!/usr/bin/env python3
"""
test_inference.py — standalone terminal tester for the Kabadiwala Connect AI layer.

What it does
------------
1. Asks you to either (1) take a photo with the webcam or (2) type a path to an image.
2. Optionally asks for approx_weight_kg (blank = None, the engine falls back to a
   category weight prior).
3. Imports the model code out of the notebook in this directory WITHOUT running the
   training / dataset-download cells, and builds a KabadiwalaAIInferenceEngine.
4. Runs engine.predict(...) and appends the price to ESTIMATED_PRICES_LIST, plus a
   full Lot-shaped record (camelCase, per the Data Dictionary) to LOT_RECORDS.

Packages
--------
    pip install opencv-python torch torchvision albumentations pillow numpy
(No importnb / ipynb package needed — the notebook is parsed as JSON, see
 load_notebook_module() below. Install importnb only if you'd rather swap that out.)

Checkpoints
-----------
Defaults match section 10 of the notebook:
    kabadiwala_work/checkpoints/segregation_best.pt
    kabadiwala_work/checkpoints/valuation_best.pt
Override with env vars SEG_CKPT / VAL_CKPT. If a checkpoint is missing the script
still runs with random weights so you can verify the plumbing and the schema — the
numbers are meaningless in that mode and it says so loudly.

Usage
-----
    python test_inference.py
"""

from __future__ import annotations

import json
import os
import re
import sys
import types
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

# --------------------------------------------------------------------------------------
# 0. Paths and the target storage lists
# --------------------------------------------------------------------------------------

HERE = Path(__file__).resolve().parent

# The prompt said ./ai_model.ipynb; the uploaded file is model.ipynb. Try both.
NOTEBOOK_CANDIDATES = ["ai_model.ipynb", "model.ipynb"]

CAPTURE_DIR = HERE / "captures"          # where webcam shots are written (Lot.photoPaths)
SEG_CKPT = os.environ.get("SEG_CKPT", str(HERE / "kabadiwala_work/checkpoints/segregation_best.pt"))
VAL_CKPT = os.environ.get("VAL_CKPT", str(HERE / "kabadiwala_work/checkpoints/valuation_best.pt"))

# >>> Requirement 3: the designated target list for the price predictions. <<<
# Field name per the Data Dictionary: Lot.estimatedValue (REST: estimated_value), ₹, double.
ESTIMATED_PRICES_LIST: List[Optional[float]] = []

# Fuller per-lot records, keyed exactly like the Dart-side Lot object.
LOT_RECORDS: List[Dict[str, Any]] = []

# --------------------------------------------------------------------------------------
# 1. Import the notebook as a module — definitions only
# --------------------------------------------------------------------------------------
# The notebook is not import-safe end to end: cells from "## 9. Execution verification"
# onward run smoke tests, download Roboflow/TrashNet data and train both pipelines.
# Importing with importnb/ipynb would execute all of that. So we read the .ipynb as JSON
# and exec only the code cells that come before the first stop marker, into a fresh
# module namespace. Those cells are pure definitions (constants, transforms, Dataset,
# both nn.Modules, the loss, EngineConfig, KabadiwalaAIInferenceEngine).

_STOP_MARKERS = (
    re.compile(r"^\s*#+\s*9\.\s"),        # "## 9. Execution verification"
    re.compile(r"^\s*#\s*Part\s*2\b", re.I),
)

_REQUIRED_NAMES = (
    "KabadiwalaAIInferenceEngine",
    "EngineConfig",
    "WasteSegregationCNN",
    "EwasteValuationMultiHeadCNN",
)


def _strip_magics(source: str) -> str:
    """Drop IPython magics / shell escapes (%pip install ..., !git clone ...)."""
    return "\n".join(
        line for line in source.splitlines()
        if not line.lstrip().startswith(("%", "!"))
    )


def find_notebook() -> Path:
    for name in NOTEBOOK_CANDIDATES:
        p = HERE / name
        if p.is_file():
            return p
    raise FileNotFoundError(
        f"No notebook found in {HERE}. Looked for: {', '.join(NOTEBOOK_CANDIDATES)}"
    )


def load_notebook_module(nb_path: Path, module_name: str = "kabadiwala_model_nb") -> types.ModuleType:
    """Exec the definition cells of `nb_path` into a new module and return it."""
    with open(nb_path, "r", encoding="utf-8") as fh:
        nb = json.load(fh)

    module = types.ModuleType(module_name)
    module.__file__ = str(nb_path)
    sys.modules[module_name] = module

    executed = 0
    for idx, cell in enumerate(nb.get("cells", [])):
        source = "".join(cell.get("source", []))

        # A markdown heading that starts the executable section = stop here.
        if cell.get("cell_type") == "markdown":
            if any(p.match(source) for p in _STOP_MARKERS):
                break
            continue

        if cell.get("cell_type") != "code":
            continue

        code = _strip_magics(source)
        if not code.strip():
            continue

        exec(compile(code, f"<{nb_path.name}:cell{idx}>", "exec"), module.__dict__)
        executed += 1

    missing = [n for n in _REQUIRED_NAMES if not hasattr(module, n)]
    if missing:
        raise ImportError(
            f"Ran {executed} cell(s) of {nb_path.name} but these are undefined: {missing}. "
            "The notebook's section numbering probably changed — adjust _STOP_MARKERS."
        )
    print(f"[model] imported {executed} definition cell(s) from {nb_path.name}")
    return module


# --------------------------------------------------------------------------------------
# 2. Build the inference engine
# --------------------------------------------------------------------------------------

def build_engine(nb: types.ModuleType):
    """Instantiate KabadiwalaAIInferenceEngine, loading checkpoints when present."""
    import torch

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    seg_path = Path(SEG_CKPT)
    val_path = Path(VAL_CKPT)
    seg_ok, val_ok = seg_path.is_file(), val_path.is_file()

    if not (seg_ok and val_ok):
        print("\n" + "!" * 78)
        print("! WARNING: running with RANDOM weights for:",
              ", ".join(n for n, ok in (("segregation", seg_ok), ("valuation", val_ok)) if not ok))
        print("! Output shape/schema is real; the predicted ₹ value is noise.")
        print("! Point SEG_CKPT / VAL_CKPT at your trained .pt files for real numbers.")
        print("!" * 78 + "\n")

    # EngineConfig mirrors section 15 of the notebook. Keep the image sizes in sync with
    # whatever VAL_IMAGE_SIZE you trained at, or the backbone sees the wrong input scale.
    config = nb.EngineConfig(
        segregation_image_size=int(os.environ.get("SEG_IMAGE_SIZE", 224)),
        valuation_image_size=int(os.environ.get("VAL_IMAGE_SIZE", 380)),
        e_waste_threshold=float(os.environ.get("E_WASTE_THRESHOLD", 0.5)),
        # mixed_plastics_rate_inr_per_kg=10.0,  # set to price the MixedPlastics route too
    )

    engine = nb.KabadiwalaAIInferenceEngine.from_checkpoints(
        segregation_ckpt=str(seg_path) if seg_ok else None,
        valuation_ckpt=str(val_path) if val_ok else None,
        config=config,
        device=device,
    )
    print(f"[model] engine ready on {device}")
    return engine


# --------------------------------------------------------------------------------------
# 3. Image input — option 1 (camera) and option 2 (file path)
# --------------------------------------------------------------------------------------

def capture_from_camera(cam_index: int = 0) -> Optional[Path]:
    """
    Open the default camera, show a preview, save one frame to captures/<uuid>.jpg.

    SPACE = capture, ESC/q = cancel. On a headless box (no GUI, imshow raises) it
    falls back to grabbing a frame after a short warm-up.
    """
    import cv2

    cap = cv2.VideoCapture(cam_index)
    if not cap.isOpened():
        print(f"[camera] could not open camera index {cam_index}.")
        return None

    CAPTURE_DIR.mkdir(parents=True, exist_ok=True)
    out_path = CAPTURE_DIR / f"{uuid.uuid4().hex}.jpg"
    frame = None

    try:
        for _ in range(10):        # let auto-exposure / white balance settle
            cap.read()

        headless = False
        while True:
            ok, live = cap.read()
            if not ok:
                print("[camera] failed to read a frame.")
                return None

            if headless:
                frame = live
                break

            try:
                cv2.imshow("Kabadiwala capture — SPACE = shoot, ESC = cancel", live)
                key = cv2.waitKey(1) & 0xFF
            except cv2.error:
                print("[camera] no display available; auto-capturing.")
                headless = True
                continue

            if key == 32:                      # SPACE
                frame = live
                break
            if key in (27, ord("q")):          # ESC / q
                print("[camera] cancelled.")
                return None
    finally:
        cap.release()
        try:
            cv2.destroyAllWindows()
        except Exception:
            pass

    if frame is None:
        return None

    cv2.imwrite(str(out_path), frame)          # imwrite expects BGR, which is what we have
    print(f"[camera] saved {out_path}")
    return out_path


def load_from_path() -> Optional[Path]:
    """Option 2: user types a path to an existing image."""
    raw = input("Path to image file: ").strip().strip('"').strip("'")
    if not raw:
        return None
    path = Path(raw).expanduser().resolve()
    if not path.is_file():
        print(f"[input] no such file: {path}")
        return None
    if path.suffix.lower() not in {".jpg", ".jpeg", ".png", ".bmp", ".webp"}:
        print(f"[input] warning: unusual extension {path.suffix}; trying anyway.")
    return path


def ask_weight() -> Optional[float]:
    """Optional approx_weight_kg. Blank -> None -> engine uses its category prior."""
    raw = input("approx_weight_kg (press Enter to skip): ").strip()
    if not raw:
        return None
    try:
        w = float(raw)
    except ValueError:
        print("[input] not a number; treating as None.")
        return None
    if w <= 0:
        print("[input] weight must be > 0; treating as None.")
        return None
    return w


# --------------------------------------------------------------------------------------
# 4. Run inference and store the value in the target list
# --------------------------------------------------------------------------------------

def run_once(engine, image_path: Path, approx_weight_kg: Optional[float]) -> Dict[str, Any]:
    """
    Feed the image through the engine and append the price to ESTIMATED_PRICES_LIST.

    engine.predict() accepts a path directly (it also takes PIL images, RGB uint8
    arrays, or normalised tensors) and returns:
        {"rest_api": {...snake_case...}, "dart_ui_state": {...camelCase...}}
    """
    result = engine.predict(str(image_path), approx_weight_kg=approx_weight_kg)

    rest = result["rest_api"]          # backend payload: estimated_value, material_category, ...
    dart = result["dart_ui_state"]     # UI payload:      estimatedValue,  category, ...

    # --- Requirement 3: pull the price out and store it ---------------------------------
    estimated_value = rest.get("estimated_value")   # double | None, ₹ (None on the
    ESTIMATED_PRICES_LIST.append(estimated_value)   # MixedPlastics route with no rate set)

    # A Lot-shaped record, field names straight from the Data Dictionary section 1.
    LOT_RECORDS.append({
        "id": str(uuid.uuid4()),                        # generated on-device at creation
        "category": dart["category"],                   # from material_category
        "subCategory": dart["subCategory"],
        "approxWeightKg": dart["approxWeightKg"],
        "photoPaths": [str(image_path)],                # local paths until sync
        "estimatedValue": dart["estimatedValue"],       # the number we just appended
        "quotedPrice": None,                            # set later by the recycler match
        "finalSaleValue": None,                         # set later at transaction close
        "createdAt": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "latitude": None,                               # fill from device GPS in the app
        "longitude": None,
        "syncStatus": "pending",
        "recyclerId": None,
    })

    print("\n--- rest_api (snake_case, what the backend receives) ---")
    print(json.dumps(rest, indent=2, ensure_ascii=False))
    print("\n--- dart_ui_state (camelCase, what the Flutter UI binds to) ---")
    print(json.dumps(dart, indent=2, ensure_ascii=False))
    print(f"\nESTIMATED_PRICES_LIST -> {ESTIMATED_PRICES_LIST}")
    return result


# --------------------------------------------------------------------------------------
# 5. Terminal loop
# --------------------------------------------------------------------------------------

MENU = """
Kabadiwala Connect — inference test
  1) Capture a photo with the camera
  2) Use an image file from disk
  3) Dump collected lots as JSON
  q) Quit
"""


def main() -> int:
    nb = load_notebook_module(find_notebook())
    engine = build_engine(nb)

    while True:
        print(MENU)
        choice = input("Choose [1/2/3/q]: ").strip().lower()

        if choice in ("q", "quit", "exit"):
            break

        if choice == "3":
            print(json.dumps(LOT_RECORDS, indent=2, ensure_ascii=False))
            continue

        if choice == "1":
            image_path = capture_from_camera(int(os.environ.get("CAM_INDEX", 0)))
        elif choice == "2":
            image_path = load_from_path()
        else:
            print("Pick 1, 2, 3 or q.")
            continue

        if image_path is None:
            continue

        weight = ask_weight()
        try:
            run_once(engine, image_path, weight)
        except Exception as exc:
            print(f"[inference] failed: {type(exc).__name__}: {exc}")

    print(f"\nSession totals: {len(LOT_RECORDS)} lot(s), prices = {ESTIMATED_PRICES_LIST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
