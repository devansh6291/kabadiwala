#!/usr/bin/env python3
"""
server.py — wraps the notebook's inference chain as a small HTTP API so the
Flutter app (which cannot run Python) can call it.

Reuses find_notebook / load_notebook_module / build_engine directly from
test_inference.py instead of re-implementing model loading, so this
stays in sync with whatever changes there.

Run with:
    uvicorn server:app --host 0.0.0.0 --port 8000

Then, on the same WiFi network (or via `adb reverse tcp:8000 tcp:8000` when
testing over USB), the Flutter app calls:
    http://<this-machine's-local-IP>:8000/classify
"""

import tempfile
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from test_inference import build_engine, find_notebook, load_notebook_module

app = FastAPI(title="Kabadiwala Connect — Classifier API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load the model ONCE at startup, not per-request — this is the expensive part.
_nb = load_notebook_module(find_notebook())
_engine = build_engine(_nb)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/classify")
async def classify(file: UploadFile = File(...), approx_weight_kg: Optional[float] = Form(None)):
    """
    Accepts one image file (+ optional approx_weight_kg), returns the
    camelCase dart_ui_state shape the Flutter app's ApiClassifierService
    expects to parse.
    """
    suffix = Path(file.filename or "upload.jpg").suffix or ".jpg"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name

    try:
        result = _engine.predict(tmp_path, approx_weight_kg=approx_weight_kg)

        if "dart_ui_state" in result:
            return result["dart_ui_state"]

        print(f"[server] WARNING: no 'dart_ui_state' key. Actual keys: {list(result.keys())}")
        return result
    finally:
        Path(tmp_path).unlink(missing_ok=True)