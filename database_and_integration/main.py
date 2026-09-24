import tempfile
from pathlib import Path
from fastapi import FastAPI, Depends, HTTPException, Query, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List, Optional
from database import get_db, engine
import models
import schema
from math import radians, sin, cos, sqrt, asin

# AI Module Imports
from ai_model.test_inference import build_engine, find_notebook, load_notebook_module

app = FastAPI(title="Kabadiwala E-connect API")

# ==========================================
# AI MODEL & MIDDLEWARE INITIALIZATION
# ==========================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load the model ONCE at startup, not per-request — this is the expensive part.
_nb = load_notebook_module(find_notebook())
_engine = build_engine(_nb)


# ==========================================
# 0. DATABASE INITIALIZATION
# ==========================================
@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(models.Base.metadata.create_all)


# ==========================================
# 1. COLLECTOR (Auth & Profile)
# ==========================================
@app.post("/collectors", response_model=schema.CollectorSchema)
async def create_or_update_collector(collector: schema.CollectorSchema, db: AsyncSession = Depends(get_db)):
    """Handles Collector OTP Login / Registration."""
    try:
        # Check if collector already exists by phone number
        query = select(models.Collector).where(models.Collector.phone_number == collector.phone_number)
        result = await db.execute(query)
        existing_collector = result.scalar_one_or_none()

        if existing_collector:
            # Update existing profile
            for key, value in collector.model_dump(exclude_unset=True).items():
                setattr(existing_collector, key, value)
            await db.commit()
            await db.refresh(existing_collector)
            return existing_collector
        else:
            # Create new profile
            new_collector = models.Collector(**collector.model_dump())
            db.add(new_collector)
            await db.commit()
            await db.refresh(new_collector)
            return new_collector
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/collectors/{phone_number}", response_model=schema.CollectorSchema)
async def get_collector(phone_number: str, db: AsyncSession = Depends(get_db)):
    query = select(models.Collector).where(models.Collector.phone_number == phone_number)
    result = await db.execute(query)
    collector = result.scalar_one_or_none()
    if not collector:
        raise HTTPException(status_code=404, detail="Collector not found")
    return collector


# ==========================================
# 2. LOTS (Offline Batch Sync)
# ==========================================
@app.post("/lots", response_model=schema.LotSchema)
async def sync_single_lot(lot: schema.LotSchema, db: AsyncSession = Depends(get_db)):
    """Accepts a single offline-created Lot from Flutter and syncs it."""
    try:
        new_lot = models.Lot(**lot.model_dump(exclude_unset=True))
        db.add(new_lot)
        await db.commit()
        await db.refresh(new_lot)
        return new_lot
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=f"Sync failed: {str(e)}")


# ==========================================
# 3. RECYCLERS & STORAGE HOSTS
# ==========================================
@app.get("/recyclers", response_model=List[schema.RecyclerSchema])
async def get_recyclers(db: AsyncSession = Depends(get_db)):
    """Fetches all authorized recyclers for proximity matching in Flutter."""
    query = select(models.Recycler).where(models.Recycler.authorization_status == "authorized")
    result = await db.execute(query)
    return result.scalars().all()

@app.get("/storage-hosts", response_model=List[schema.StorageHostSchema])
async def get_storage_hosts(db: AsyncSession = Depends(get_db)):
    """Fetches large Kabadiwalas offering custody storage."""
    query = select(models.StorageHost)
    result = await db.execute(query)
    return result.scalars().all()


# ==========================================
# 4. POOLING SYSTEM
# ==========================================
@app.post("/pools", response_model=schema.PoolSchema)
async def create_pool(pool: schema.PoolSchema, db: AsyncSession = Depends(get_db)):
    try:
        pool_dict = pool.model_dump(exclude={"entries", "current_weight_kg"}, exclude_unset=True)
        new_pool = models.Pool(**pool_dict)
        db.add(new_pool)
        
        # Add nested entries
        for entry in pool.entries:
            entry_dict = entry.model_dump()
            entry_dict["pool_id"] = new_pool.id # Force link entry to pool
            new_entry = models.LotPoolEntry(**entry_dict)
            db.add(new_entry)
            
        await db.commit()
        return pool
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/pools", response_model=List[schema.PoolSchema])
async def get_pools(category: Optional[str] = None, recycler_id: Optional[str] = None, db: AsyncSession = Depends(get_db)):
    query = select(models.Pool)
    if category:
        query = query.where(models.Pool.category == category)
    if recycler_id:
        query = query.where(models.Pool.target_recycler_id == recycler_id)
    result = await db.execute(query)
    return result.scalars().all()

@app.post("/pools/{pool_id}/contribute")
async def contribute_to_pool(pool_id: str, contribution: schema.ContributionSchema, db: AsyncSession = Depends(get_db)):
    try:
        new_entry = models.LotPoolEntry(
            pool_id=pool_id,
            lot_id=contribution.lot_id,
            weight_kg=contribution.weight_kg,
            collector_label=contribution.collector_label
        )
        db.add(new_entry)
        await db.commit()
        return {"status": "success"}
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))


# ==========================================
# 5. TRANSACTIONS & FORM-6 MANIFESTS
# ==========================================
@app.post("/transactions", response_model=schema.TransactionSchema)
async def create_transaction(tx: schema.TransactionSchema, db: AsyncSession = Depends(get_db)):
    try:
        new_tx = models.Transaction(**tx.model_dump(exclude_unset=True))
        db.add(new_tx)
        await db.commit()
        await db.refresh(new_tx)
        return new_tx
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/manifests/checkpoint", response_model=schema.Form6ManifestSchema)
async def create_manifest(manifest: schema.Form6ManifestSchema, db: AsyncSession = Depends(get_db)):
    try:
        new_manifest = models.DigitalForm6Manifest(**manifest.model_dump(exclude_unset=True))
        db.add(new_manifest)
        await db.commit()
        await db.refresh(new_manifest)
        return new_manifest
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))


# ==========================================
# 6. MARKET PRICES & NEWS
# ==========================================
@app.get("/prices", response_model=List[schema.PriceDatasetEntrySchema])
async def get_prices(db: AsyncSession = Depends(get_db)):
    """Provides market trends for scrap prices to the UI."""
    query = select(models.PriceDatasetEntry).order_by(models.PriceDatasetEntry.date.desc())
    result = await db.execute(query)
    return result.scalars().all()

@app.get("/news", response_model=List[schema.NewsItemSchema])
async def get_news(db: AsyncSession = Depends(get_db)):
    """Provides industry news updates to the UI."""
    query = select(models.NewsItem).order_by(models.NewsItem.date.desc())
    result = await db.execute(query)
    return result.scalars().all()


# ==========================================
# 7. NEARBY RECYCLERS & KABADIWALAS (GEO-QUERY)
# ==========================================
@app.get("/recyclers/nearby", response_model=List[schema.RecyclerSchema])
async def get_nearby_recyclers(
    lat: float = Query(..., description="Collector latitude"),
    lng: float = Query(..., description="Collector longitude"),
    radius_km: float = Query(15.0, description="Search radius in kilometers"),
    material: Optional[str] = Query(None, description="Filter by accepted material category"),
    db: AsyncSession = Depends(get_db)
):
    """
    Finds authorized recyclers within the given radius or whose service area covers the collector,
    optionally filtered by the scrap material category.
    """
    try:
        # Fetch all authorized, non-storage recyclers from MySQL
        query = select(models.Recycler).where(
            models.Recycler.authorization_status == "authorized",
            models.Recycler.is_storage_only == False
        )
        result = await db.execute(query)
        recyclers = result.scalars().all()

        nearby_recyclers = []
        
        # Haversine formula calculation in Python (ideal for moderate directory sizes)
        for r in recyclers:
            if material and r.materials_accepted:
                if material not in r.materials_accepted:
                    continue

            lat1, lon1 = radians(lat), radians(lng)
            lat2, lon2 = radians(r.facility_location_lat), radians(r.facility_location_lng)
            
            dlon = lon2 - lon1
            dlat = lat2 - lat1
            a = sin(dlat / 2)**2 + cos(lat1) * cos(lat2) * sin(dlon / 2)**2
            c = 2 * asin(sqrt(a))
            distance_km = 6371 * c

            effective_radius = max(radius_km, r.service_area_radius_km)
            if distance_km <= effective_radius:
                nearby_recyclers.append(r)

        return nearby_recyclers
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Geo-query failed: {str(e)}")


@app.get("/storage-hosts/nearby", response_model=List[schema.StorageHostSchema])
async def get_nearby_storage_hosts(
    lat: float = Query(..., description="Collector latitude"),
    lng: float = Query(..., description="Collector longitude"),
    radius_km: float = Query(20.0, description="Search radius in kilometers"),
    db: AsyncSession = Depends(get_db)
):
    """
    Finds nearby large Kabadiwalas / Storage Hosts offering paid custody for pooled items.
    """
    try:
        query = select(models.StorageHost).where(models.StorageHost.available_capacity > 0)
        result = await db.execute(query)
        hosts = result.scalars().all()

        nearby_hosts = []
        for h in hosts:
            lat1, lon1 = radians(lat), radians(lng)
            lat2, lon2 = radians(h.latitude), radians(h.longitude)
            
            dlon = lon2 - lon1
            dlat = lat2 - lat1
            a = sin(dlat / 2)**2 + cos(lat1) * cos(lat2) * sin(dlon / 2)**2
            c = 2 * asin(sqrt(a))
            distance_km = 6371 * c

            if distance_km <= radius_km:
                nearby_hosts.append(h)

        return nearby_hosts
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Storage geo-query failed: {str(e)}")


# ==========================================
# 8. AI CLASSIFICATION & HEALTH
# ==========================================
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