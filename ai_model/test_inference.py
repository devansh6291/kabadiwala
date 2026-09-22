#!/usr/bin/env python3
"""
test_inference.py — loads model.ipynb as a plain Python module and exposes
an inference engine from it, so server.py doesn't need to duplicate any
model-loading logic.

Reconstructed to match server.py's existing usage:
    _nb = load_notebook_module(find_notebook())
    _engine = build_engine(_nb)
    _engine.predict(image_path, approx_weight_kg=...)
"""

from __future__ import annotations

import matplotlib
matplotlib.use("Agg")  # non-interactive backend — no popup windows, ever

import ast
import json
import types
from pathlib import Path


def find_notebook(name: str = "model.ipynb") -> Path:
    here = Path(__file__).parent
    candidate = here / name
    if candidate.exists():
        return candidate
    matches = list(here.glob("*.ipynb"))
    if matches:
        return matches[0]
    raise FileNotFoundError(f"No notebook found in {here} (looked for '{name}')")


def _strip_magics(source: str) -> str:
    """Remove Jupyter magic/shell lines (%..., !...) that aren't valid Python."""
    return "\n".join(
        line for line in source.splitlines()
        if not line.lstrip().startswith(("%", "!"))
    )


def load_notebook_module(nb_path: Path) -> types.ModuleType:
    """Execute the notebook's code cells STATEMENT BY STATEMENT into a fresh
    module namespace, so a failing line (e.g. a training loop needing data
    we don't have) doesn't block a class/function defined later in the
    same cell from being created.
    """
    nb_path = Path(nb_path)
    nb = json.loads(nb_path.read_text(encoding="utf-8"))

    module = types.ModuleType("model_notebook")
    module.__file__ = str(nb_path)

    code_cells = [c for c in nb.get("cells", []) if c.get("cell_type") == "code"]
    print(f"[model] imported {len(code_cells)} definition cell(s) from {nb_path.name}")

    ok_count = fail_count = 0
    for idx, cell in enumerate(code_cells):
        source = _strip_magics("".join(cell.get("source", [])))
        if not source.strip():
            continue

        try:
            tree = ast.parse(source)
        except SyntaxError as exc:
            print(f"[model] WARNING: cell {idx} has invalid syntax, skipped: {exc}")
            continue

        for node in tree.body:
            stmt_src = ast.get_source_segment(source, node) or ""
            try:
                code = compile(
                    ast.Module(body=[node], type_ignores=[]),
                    f"<{nb_path.name}:cell{idx}>",
                    "exec",
                )
                exec(code, module.__dict__)
                ok_count += 1
            except Exception as exc:
                fail_count += 1
                label = stmt_src.strip().splitlines()[0][:60] if stmt_src else "?"
                print(f"[model] WARNING: cell {idx} stmt '{label}' failed: {exc}")

    print(f"[model] {ok_count} statement(s) executed, {fail_count} failed")
    return module


def build_engine(nb_module: types.ModuleType):
    """Wrap the notebook's predict_lot_price() into an object with a
    .predict() method, matching how server.py calls it.

    predict_lot_price(photoPaths: List[str], approxWeightKg: float, ...) is
    the notebook's actual "full inference chain for one lot" entry point —
    confirmed via its own docstring and signature.
    """
    predict_fn = getattr(nb_module, "predict_lot_price", None) or getattr(
        nb_module, "estimate_recycle_price", None
    )
    if predict_fn is None:
        available = [n for n in dir(nb_module) if not n.startswith("_")]
        raise AttributeError(
            "Could not find predict_lot_price or estimate_recycle_price "
            f"in the notebook. Available names: {available}"
        )

    class _NotebookEngine:
        def predict(self, image_path: str, approx_weight_kg=None):
            weight = approx_weight_kg if approx_weight_kg is not None else 1.0
            result = predict_fn(
                photoPaths=[image_path],
                approxWeightKg=weight,
            )
            return result

    return _NotebookEngine()