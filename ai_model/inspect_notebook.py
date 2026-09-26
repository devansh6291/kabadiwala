import inspect
from ai_model.test_inference import find_notebook, load_notebook_module

nb = load_notebook_module(find_notebook())

FUNCS_TO_CHECK = [
    "predict_pipeline1", "predict_pipeline2",
    "predict_lot_price", "estimate_recycle_price", "predict_estimated_value",
    "load_image", "validate_lot",
    "extract_cv_features", "build_feature_matrix",
]

print("\n=== FUNCTION SIGNATURES ===")
for name in FUNCS_TO_CHECK:
    fn = getattr(nb, name, None)
    if fn is None:
        print(f"{name}: NOT FOUND")
        continue
    try:
        print(f"{name}{inspect.signature(fn)}")
        if fn.__doc__:
            print(f"    doc: {fn.__doc__.strip()[:200]}")
    except (TypeError, ValueError) as exc:
        print(f"{name}: could not inspect ({exc})")

print("\n=== KEY OBJECTS ===")
for name in ["p1_model", "p2_model", "price_model", "category_encoder", "subcategory_encoder"]:
    obj = getattr(nb, name, None)
    print(f"{name}: {type(obj)}")

print("\n=== REFERENCE DATA ===")
for name in ["LOT_CATEGORIES", "CANONICAL_SUBCATEGORIES", "COMPONENT_KEYS",
             "METAL_KEYS", "FEATURE_COLUMNS", "WEIGHT_PRIORS_KG"]:
    val = getattr(nb, name, None)
    print(f"{name} = {val}")

if hasattr(nb, "category_encoder"):
    print(f"\ncategory_encoder.classes_ = {nb.category_encoder.classes_}")
if hasattr(nb, "subcategory_encoder"):
    print(f"subcategory_encoder.classes_ = {nb.subcategory_encoder.classes_}")