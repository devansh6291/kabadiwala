import tempfile
import json
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
import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from ai_model.test_inference import build_engine, find_notebook, load_notebook_module

app = FastAPI(title="Kabadiwala E-connect API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

_nb = load_notebook_module(find_notebook())
_engine = build_engine(_nb)

@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(models.Base.metadata.create_all)

@app.post("/collectors", response_model=schema.CollectorSchema)
async def create_or_update_collector(collector: schema.CollectorSchema, db: AsyncSession = Depends(get_db)):
    try:
        query = select(models.Collector).where(models.Collector.phone_number == collector.phone_number)
        result = await db.execute(query)
        existing_collector = result.scalar_one_or_none()

        if existing_collector:
            for key, value in collector.model_dump(exclude_unset=True).items():
                setattr(existing_collector, key, value)
            await db.commit()
            await db.refresh(existing_collector)
            return existing_collector
        else:
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

@app.post("/lots", response_model=schema.LotSchema)
async def sync_single_lot(lot: schema.LotSchema, db: AsyncSession = Depends(get_db)):
    try:
        new_lot = models.Lot(**lot.model_dump(exclude_unset=True))
        db.add(new_lot)
        await db.commit()
        await db.refresh(new_lot)
        return new_lot
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=f"Sync failed: {str(e)}")

@app.get("/recyclers")
async def get_recyclers(category: Optional[str] = Query(None), db: AsyncSession = Depends(get_db)):
    """Fetches all authorized recyclers with manual JSON formatting to prevent Pydantic validation crashes."""
    try:
        query = select(models.Recycler).where(models.Recycler.authorization_status == "authorized")
        result = await db.execute(query)
        recyclers = result.scalars().all()
        
        print(f"\n[DEBUG] /recyclers found {len(recyclers)} rows in MySQL.")
        
        formatted = []
        for r in recyclers:
            # Safe JSON parsing for materials_accepted
            mats = r.materials_accepted or []
            if isinstance(mats, str):
                try:
                    mats = json.loads(mats)
                except:
                    mats = [m.strip() for m in mats.split(",")]
            
            # Safe JSON parsing for offered_rates
            rates = r.offered_rates or {}
            if isinstance(rates, str):
                try:
                    rates = json.loads(rates)
                except:
                    rates = {}

            if category:
                if mats and not any(category.lower() == m.lower() for m in mats):
                    continue

            formatted.append({
                "recycler_id": r.recycler_id,
                "recyclerId": r.recycler_id,
                "name": r.name,
                "company_name": r.name,
                "facility_location_lat": float(r.facility_location_lat or 0.0),
                "facility_location_lng": float(r.facility_location_lng or 0.0),
                "facilityLat": float(r.facility_location_lat or 0.0),
                "facilityLng": float(r.facility_location_lng or 0.0),
                "materials_accepted": mats,
                "materialsAccepted": mats,
                "authorization_number": r.authorization_number or "",
                "authorizationNumber": r.authorization_number or "",
                "authorization_status": r.authorization_status or "authorized",
                "authorizationStatus": r.authorization_status or "authorized",
                "contact_details": r.contact_details or "",
                "contactDetails": r.contact_details or "",
                "offered_rates": rates,
                "offeredRates": rates,
                "pickup_availability": r.pickup_availability or "Immediate",
                "pickupAvailability": r.pickup_availability or "Immediate",
                "service_area_radius_km": float(r.service_area_radius_km or 15.0),
                "serviceAreaRadiusKm": float(r.service_area_radius_km or 15.0),
                "has_own_logistics": bool(r.has_own_logistics),
                "hasOwnLogistics": bool(r.has_own_logistics),
                "min_vehicle_capacity_kg": float(r.min_vehicle_capacity_kg or 0.0),
                "minVehicleCapacityKg": float(r.min_vehicle_capacity_kg or 0.0),
                "is_storage_only": bool(r.is_storage_only),
                "isStorageOnly": bool(r.is_storage_only),
                "storage_rate_per_item_week": float(r.storage_rate_per_item_week or 0.0) if hasattr(r, 'storage_rate_per_item_week') and r.storage_rate_per_item_week else 0.0,
                "storageRatePerItemWeek": float(r.storage_rate_per_item_week or 0.0) if hasattr(r, 'storage_rate_per_item_week') and r.storage_rate_per_item_week else 0.0,
            })
        return formatted
    except Exception as e:
        print(f"[ERROR in /recyclers]: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))
    
@app.get("/storage-hosts")
async def get_storage_hosts(db: AsyncSession = Depends(get_db)):
    """Fetches large Kabadiwalas offering custody storage with safe manual formatting."""
    try:
        query = select(models.StorageHost)
        result = await db.execute(query)
        hosts = result.scalars().all()
        
        formatted = []
        for h in hosts:
            formatted.append({
                "host_id": h.host_id,
                "hostId": h.host_id,
                "name": h.name,
                "latitude": float(h.latitude or 0.0),
                "longitude": float(h.longitude or 0.0),
                "weekly_rate_per_item": float(h.weekly_rate_per_item or 0.0),
                "weeklyRatePerItem": float(h.weekly_rate_per_item or 0.0),
                "available_capacity": int(h.available_capacity or 0),
                "availableCapacity": int(h.available_capacity or 0),
                "rating": float(h.rating or 0.0),
            })
        return formatted
    except Exception as e:
        print(f"[ERROR in /storage-hosts]: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/pools", response_model=schema.PoolSchema)
async def create_pool(pool: schema.PoolSchema, db: AsyncSession = Depends(get_db)):
    try:
        pool_dict = pool.model_dump(exclude={"entries", "current_weight_kg"}, exclude_unset=True)
        new_pool = models.Pool(**pool_dict)
        db.add(new_pool)
        
        for entry in pool.entries:
            entry_dict = entry.model_dump()
            entry_dict["pool_id"] = new_pool.id
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
    pools = result.scalars().all()

    # Attach entries to each pool object so Flutter correctly computes weights and progress bars
    response_pools = []
    for p in pools:
        entries_query = select(models.LotPoolEntry).where(models.LotPoolEntry.pool_id == p.id)
        entries_res = await db.execute(entries_query)
        entries = entries_res.scalars().all()
        
        total_wt = sum(e.weight_kg for e in entries)
        response_pools.append({
            "poolId": p.id,
            "materialCategory": p.category,
            "recyclerId": p.recycler_id,
            "targetThresholdKg": p.threshold_kg,
            "currentWeightKg": total_wt,
            "status": p.status,
            "storageHostId": p.storage_kabadiwala_id,
            "entries": [{"lotId": e.lot_id, "collectorLabel": e.collector_label, "weightKg": e.weight_kg} for e in entries],
            "createdAt": p.created_at
        })
    return response_pools

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

@app.get("/prices", response_model=List[schema.PriceDatasetEntrySchema])
async def get_prices(db: AsyncSession = Depends(get_db)):
    query = select(models.PriceDatasetEntry).order_by(models.PriceDatasetEntry.date.desc())
    result = await db.execute(query)
    return result.scalars().all()

@app.get("/news")
async def get_news(db: AsyncSession = Depends(get_db)):
    query = select(models.NewsItem).order_by(models.NewsItem.date.desc())
    result = await db.execute(query)
    news_records = result.scalars().all()
    
    formatted_news = []
    for article in news_records:
        formatted_news.append({
            "id": article.id,
            "title": article.title,
            "headline": article.title,
            "source": article.source,
            "date": str(article.date),
            "published_at": str(article.date),
            "snippet": article.snippet,
            "body": article.snippet,
            "url": article.url
        })
    return formatted_news

@app.get("/recyclers/nearby")
async def get_nearby_recyclers(
    lat: float = Query(...),
    lng: float = Query(...),
    radius_km: float = Query(50.0),
    material: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    try:
        query = select(models.Recycler).where(
            models.Recycler.authorization_status == "authorized",
            models.Recycler.is_storage_only == False
        )
        result = await db.execute(query)
        recyclers = result.scalars().all()

        nearby_with_distance = []
        for r in recyclers:
            accepted = r.materials_accepted or []
            if isinstance(accepted, str):
                try:
                    accepted = json.loads(accepted)
                except:
                    accepted = [m.strip() for m in accepted.split(",")]

            if material and accepted:
                if not any(material.lower() == m.lower() for m in accepted):
                    continue

            r_lat = r.facility_location_lat or 0.0
            r_lng = r.facility_location_lng or 0.0
            lat1, lon1 = radians(lat), radians(lng)
            lat2, lon2 = radians(r_lat), radians(r_lng)
            dlon = lon2 - lon1
            dlat = lat2 - lat1
            a = sin(dlat / 2)**2 + cos(lat1) * cos(lat2) * sin(dlon / 2)**2
            c = 2 * asin(sqrt(a))
            distance_km = 6371 * c

            effective_radius = max(radius_km, (r.service_area_radius_km or 0.0))
            if distance_km <= effective_radius:
                nearby_with_distance.append((distance_km, r))

        nearby_with_distance.sort(key=lambda item: item[0])

        formatted_results = []
        for dist, r in nearby_with_distance:
            mats = r.materials_accepted
            if isinstance(mats, str):
                try:
                    mats = json.loads(mats)
                except:
                    mats = [m.strip() for m in mats.split(",")]

            rates = r.offered_rates
            if isinstance(rates, str):
                try:
                    rates = json.loads(rates)
                except:
                    rates = {}

            recycler_name = getattr(r, "name", "Unknown")
            formatted_results.append({
                "recycler_id": r.recycler_id,
                "name": recycler_name,
                "company_name": recycler_name,
                "facility_lat": float(r.facility_location_lat or 0.0),
                "facility_lng": float(r.facility_location_lng or 0.0),
                "facility_location_lat": float(r.facility_location_lat or 0.0),
                "facility_location_lng": float(r.facility_location_lng or 0.0),
                "materials_accepted": mats,
                "authorization_number": getattr(r, "authorization_number", ""),
                "authorization_status": getattr(r, "authorization_status", ""),
                "contact_details": getattr(r, "contact_details", ""),
                "offered_rates": rates,
                "distance_km": round(dist, 2),
                "min_vehicle_capacity_kg": float(r.min_vehicle_capacity_kg or 0.0),
                "pickup_availability": getattr(r, "pickup_availability", "Immediate"),
                "is_storage_only": bool(r.is_storage_only)
            })
        return formatted_results
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/storage-hosts/nearby", response_model=List[schema.StorageHostSchema])
async def get_nearby_storage_hosts(
    lat: float = Query(..., description="Collector latitude"),
    lng: float = Query(..., description="Collector longitude"),
    radius_km: float = Query(15.0, description="Search radius in kilometers"),
    db: AsyncSession = Depends(get_db)
):
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

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/classify")
async def classify(file: UploadFile = File(...), approx_weight_kg: Optional[float] = Form(None)):
    suffix = Path(file.filename or "upload.jpg").suffix or ".jpg"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name
    try:
        result = _engine.predict(tmp_path, approx_weight_kg=approx_weight_kg)
        if "dart_ui_state" in result:
            return result["dart_ui_state"]
        return result
    finally:
        Path(tmp_path).unlink(missing_ok=True)