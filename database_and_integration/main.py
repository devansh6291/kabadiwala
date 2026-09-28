import tempfile
import json
from pathlib import Path
from datetime import datetime, timezone
from fastapi import FastAPI, Depends, HTTPException, Query, File, UploadFile, Form, Body
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List, Optional
from database import get_db, engine
import models
import schema
from external_apis import get_live_metal_benchmarks, get_live_news, get_nearby_recycling_points
from math import radians, sin, cos, sqrt, asin
import sys
import os
import uuid
import asyncio
import jwt

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
app = FastAPI(title="Kabadiwala E-connect API")

_firebase_project_id = os.getenv("FIREBASE_PROJECT_ID", "kabadiwalaconnect-8c8c4")
_firebase_key_client = jwt.PyJWKClient(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"
)
_bearer_auth = HTTPBearer(auto_error=False)
_demo_recycler_phone = "+911234567891"
_demo_recycler_id = "sample-recycler-indore-01"


async def get_firebase_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_auth),
) -> dict:
    """Verify and decode a client-issued Firebase ID token."""
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Firebase sign-in required")

    def _verify_token() -> dict:
        signing_key = _firebase_key_client.get_signing_key_from_jwt(credentials.credentials)
        return jwt.decode(
            credentials.credentials,
            signing_key.key,
            algorithms=["RS256"],
            audience=_firebase_project_id,
            issuer=f"https://securetoken.google.com/{_firebase_project_id}",
            options={"require": ["exp", "iat", "sub"]},
        )

    try:
        claims = await asyncio.to_thread(_verify_token)
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired Firebase ID token") from exc

    return claims


async def require_demo_recycler(
    claims: dict = Depends(get_firebase_user),
) -> dict:
    """Resolve recycler access from the verified phone-to-profile mapping."""
    phone = str(claims.get("phone_number", ""))
    if phone != _demo_recycler_phone:
        raise HTTPException(status_code=403, detail="This account is not linked to a recycler profile")
    return {"uid": claims["sub"], "phone_number": phone, "recycler_id": _demo_recycler_id}

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        origin.strip()
        for origin in os.getenv("CORS_ALLOW_ORIGINS", "*").split(",")
        if origin.strip()
    ],
    # Flutter web development uses a random localhost port. Firebase Hosting
    # can be opened on either default project domain (or a preview channel).
    # Keep custom production domains explicit in CORS_ALLOW_ORIGINS.
    allow_origin_regex=(
        r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
        r"|^https://kabadiwalaconnect-8c8c4(--[a-z0-9-]+)?\.(web\.app|firebaseapp\.com)$"
    ),
    allow_methods=["*"],
    allow_headers=["*"],
)

if os.getenv("DISABLE_ML", "false").lower() == "true":
    # Small free-tier instances can't reliably hold the PyTorch models.
    _engine = None
else:
    from ai_model.test_inference import build_engine, find_notebook, load_notebook_module

    _nb = load_notebook_module(find_notebook())
    _engine = build_engine(_nb)

@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(models.Base.metadata.create_all)

@app.on_event("shutdown")
async def shutdown():
    # Dispose the async connection pool on normal shutdown and when Uvicorn
    # has to abort startup (for example, because the configured port is busy).
    await engine.dispose()

@app.post("/collectors", response_model=schema.CollectorSchema)
async def create_or_update_collector(collector: schema.CollectorSchema, db: AsyncSession = Depends(get_db)):
    try:
        query = select(models.Collector).where(models.Collector.phone_number == collector.phone_number)
        result = await db.execute(query)
        existing_collector = result.scalar_one_or_none()

        if existing_collector:
            for key, value in collector.model_dump(exclude_unset=True, by_alias=False).items():
                setattr(existing_collector, key, value)
            await db.commit()
            await db.refresh(existing_collector)
            return existing_collector
        else:
            new_collector = models.Collector(**collector.model_dump(by_alias=False))
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
        values = lot.model_dump(exclude_unset=True, by_alias=False)
        new_lot = await db.get(models.Lot, lot.id)
        if new_lot is None:
            new_lot = models.Lot(**values)
            db.add(new_lot)
        else:
            for key, value in values.items():
                setattr(new_lot, key, value)
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

            permit_source_url = None
            permit_valid_until = None
            if r.authorization_number == "AWE-55589":
                permit_source_url = "https://www.mppcb.mp.gov.in/proc/Unique-Eco-Recycle-CCA-Renewal.pdf"
                permit_valid_until = "2027-07-31"

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
                "authorizationSource": "Madhya Pradesh Pollution Control Board permit" if permit_source_url else None,
                "authorizationSourceUrl": permit_source_url,
                "authorizationValidUntil": permit_valid_until,
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
        pool_dict = pool.model_dump(exclude={"entries", "current_weight_kg"}, exclude_unset=True, by_alias=False)
        new_pool = models.Pool(**pool_dict)
        db.add(new_pool)
        
        for entry in pool.entries:
            entry_dict = entry.model_dump(by_alias=False)
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
        query = query.where(models.Pool.recycler_id == recycler_id)
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
        new_tx = models.Transaction(**tx.model_dump(exclude_unset=True, by_alias=False))
        db.add(new_tx)
        lot = await db.get(models.Lot, tx.lot_id)
        if lot is not None and (
            tx.payment_status.lower() in {"paid", "settled"}
            or tx.transaction_status.lower() in {"completed", "closed"}
        ):
            location = "Unknown"
            if lot.latitude is not None and lot.longitude is not None:
                location = f"{lot.latitude:.5f},{lot.longitude:.5f}"
            db.add(models.PriceDatasetEntry(
                material_category=lot.category,
                material_sub_category=lot.sub_category,
                location=location,
                date=datetime.now(timezone.utc),
                buying_price=tx.final_price / max(lot.approx_weight_kg, 0.001),
                selling_price=tx.quoted_price / max(lot.approx_weight_kg, 0.001),
                unit="per_kg",
                recycler_id=tx.recycler_id,
            ))
        await db.commit()
        await db.refresh(new_tx)
        return new_tx
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/logistics-requests", response_model=schema.LogisticsRequestSchema)
async def create_logistics_request(
    request: schema.LogisticsRequestSchema,
    current_user: dict = Depends(get_firebase_user),
    db: AsyncSession = Depends(get_db),
):
    if str(current_user.get("phone_number", "")) == _demo_recycler_phone:
        raise HTTPException(status_code=403, detail="Recycler accounts cannot submit collector logistics requests")
    caller_digits = "".join(ch for ch in str(current_user.get("phone_number", "")) if ch.isdigit())[-10:]
    request_digits = "".join(ch for ch in str(request.collector_phone or "") if ch.isdigit())[-10:]
    if not caller_digits or caller_digits != request_digits:
        raise HTTPException(status_code=403, detail="Logistics request must belong to the signed-in collector")
    try:
        existing_result = await db.execute(
            select(models.LogisticsRequest).where(
                models.LogisticsRequest.lot_id == request.lot_id,
                models.LogisticsRequest.recycler_id == request.recycler_id,
                models.LogisticsRequest.status.in_(["requested", "accepted"]),
            )
        )
        row = existing_result.scalars().first()
        values = request.model_dump(exclude_unset=True, by_alias=False)
        if row is None:
            row = models.LogisticsRequest(**values)
            db.add(row)
        await db.commit()
        await db.refresh(row)
        return row
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/recycler-dashboard/{recycler_id}")
async def get_recycler_dashboard(
    recycler_id: str,
    current_user: dict = Depends(require_demo_recycler),
    db: AsyncSession = Depends(get_db),
):
    """Dashboard feed scoped to the verified Firebase recycler account."""
    if recycler_id != current_user["recycler_id"]:
        raise HTTPException(status_code=403, detail="Recycler profile access denied")
    if recycler_id == "sample-recycler-indore-01":
        count = await db.execute(
            select(models.LogisticsRequest.request_id).where(
                models.LogisticsRequest.recycler_id == recycler_id
            )
        )
        if not count.first():
            now = datetime.now(timezone.utc)
            db.add_all([
                models.LogisticsRequest(
                    request_id="00000000-0000-4000-8000-000000001001",
                    recycler_id=recycler_id,
                    collector_id="00000000-0000-4000-8000-000000001101",
                    collector_name="Ramesh Kumar",
                    collector_phone="+91 90000 00001",
                    collector_location="Indore, Madhya Pradesh",
                    lot_id="00000000-0000-4000-8000-000000002001",
                    category="OtherEwaste",
                    sub_category="LCD Panel",
                    approx_weight_kg=14.5,
                    estimated_value=1160,
                    quoted_price=1015,
                    lot_latitude=22.7241,
                    lot_longitude=75.8622,
                    photo_refs=[],
                    manifest_id="DEMO-F6-1001",
                    status="requested",
                    is_sample_data=True,
                    created_at=now,
                ),
                models.LogisticsRequest(
                    request_id="00000000-0000-4000-8000-000000001002",
                    recycler_id=recycler_id,
                    collector_id="00000000-0000-4000-8000-000000001102",
                    collector_name="Savitri Devi",
                    collector_phone="+91 90000 00002",
                    collector_location="Vijay Nagar, Indore",
                    lot_id="00000000-0000-4000-8000-000000002002",
                    category="PCB",
                    sub_category="Motherboard",
                    approx_weight_kg=8.0,
                    estimated_value=1440,
                    quoted_price=1280,
                    lot_latitude=22.7520,
                    lot_longitude=75.8937,
                    photo_refs=[],
                    status="requested",
                    is_sample_data=True,
                    created_at=now,
                ),
            ])
            await db.commit()

    profile_result = await db.execute(
        select(models.Recycler).where(models.Recycler.recycler_id == recycler_id)
    )
    recycler = profile_result.scalars().first()
    if recycler is None and recycler_id == "sample-recycler-indore-01":
        profile = {
            "recyclerId": recycler_id,
            "name": "GreenLoop Materials Recovery",
            "facilityLat": 22.7196,
            "facilityLng": 75.8577,
            "materialsAccepted": ["PCB", "CRT", "Cables", "Battery", "Motor", "MixedPlastics", "OtherEwaste"],
            "authorizationNumber": "DEMO-CCA-2026-014",
            "authorizationStatus": "sample",
            "contactDetails": "Contact details unavailable in presentation profile",
            "offeredRates": {"PCB": 180, "CRT": 8, "Cables": 90, "Battery": 40, "Motor": 60, "MixedPlastics": 15},
            "pickupAvailability": "Scheduled",
            "serviceAreaRadiusKm": 50,
        }
    elif recycler is None:
        raise HTTPException(status_code=404, detail="Recycler profile not found")
    else:
        profile = {
            "recyclerId": recycler.recycler_id,
            "name": recycler.name,
            "facilityLat": recycler.facility_location_lat,
            "facilityLng": recycler.facility_location_lng,
            "materialsAccepted": recycler.materials_accepted or [],
            "authorizationNumber": recycler.authorization_number,
            "authorizationStatus": recycler.authorization_status,
            "contactDetails": recycler.contact_details,
            "offeredRates": recycler.offered_rates or {},
            "pickupAvailability": recycler.pickup_availability,
            "serviceAreaRadiusKm": recycler.service_area_radius_km,
        }

    request_result = await db.execute(
        select(models.LogisticsRequest)
        .where(models.LogisticsRequest.recycler_id == recycler_id)
        .order_by(models.LogisticsRequest.created_at.desc())
    )
    requests = [{
        "requestId": row.request_id,
        "collectorId": row.collector_id,
        "collectorName": row.collector_name,
        "collectorPhone": row.collector_phone,
        "collectorLocation": row.collector_location,
        "lotId": row.lot_id,
        "category": row.category,
        "subCategory": row.sub_category,
        "approxWeightKg": row.approx_weight_kg,
        "estimatedValue": row.estimated_value,
        "quotedPrice": row.quoted_price,
        "lotLatitude": row.lot_latitude,
        "lotLongitude": row.lot_longitude,
        "photoRefs": row.photo_refs or [],
        "manifestId": row.manifest_id,
        "status": row.status,
        "isSampleData": row.is_sample_data,
        "createdAt": row.created_at.isoformat() if row.created_at else None,
    } for row in request_result.scalars().all()]

    ledger_rows = (await db.execute(select(models.Form6CheckpointLedger))).scalars().all()
    manifests = []
    for ledger in ledger_rows:
        payload = ledger.payload or {}
        target_id = payload.get("destination_recycler_id") or payload.get("destinationRecyclerId")
        if target_id == recycler_id:
            payload.setdefault("manifest_id", ledger.manifest_id)
            manifests.append(payload)
    if not manifests and recycler_id == "sample-recycler-indore-01":
        manifests.append({
            "manifestId": "DEMO-F6-1001",
            "lotReferenceId": "00000000-0000-4000-8000-000000002001",
            "senderName": "Ramesh Kumar",
            "materialType": "OtherEwaste · LCD Panel",
            "quantity": 14.5,
            "destinationRecyclerId": recycler_id,
            "status": "Draft for presentation",
            "sampleData": True,
        })
    return {"profile": profile, "requests": requests, "manifests": manifests}

@app.patch("/logistics-requests/{request_id}")
async def decide_logistics_request(
    request_id: str,
    status: str = Body(..., embed=True),
    recycler_id: str = Query(...),
    current_user: dict = Depends(require_demo_recycler),
    db: AsyncSession = Depends(get_db),
):
    if recycler_id != current_user["recycler_id"]:
        raise HTTPException(status_code=403, detail="Recycler profile access denied")
    if status not in {"accepted", "declined"}:
        raise HTTPException(status_code=422, detail="Decision must be accepted or declined")
    row = await db.get(models.LogisticsRequest, request_id)
    if row is None or row.recycler_id != recycler_id:
        raise HTTPException(status_code=404, detail="Request not found for this recycler")
    row.status = status
    await db.commit()
    return {"requestId": row.request_id, "recyclerId": row.recycler_id, "status": row.status}

@app.get("/transactions", response_model=List[schema.TransactionSchema])
async def list_transactions(
    collector_id: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    query = select(models.Transaction).order_by(models.Transaction.created_at.desc())
    if collector_id:
        query = query.where(models.Transaction.collector_id == collector_id)
    result = await db.execute(query)
    return result.scalars().all()

@app.post("/payments", response_model=schema.PaymentRecordSchema)
async def record_payment(payment: schema.PaymentRecordSchema, db: AsyncSession = Depends(get_db)):
    if payment.method not in {"cash", "digital"}:
        raise HTTPException(status_code=422, detail="Payment method must be cash or digital")
    try:
        row = await db.get(models.PaymentRecord, payment.id)
        values = payment.model_dump(exclude_unset=True, by_alias=False)
        if row is None:
            row = models.PaymentRecord(**values)
            db.add(row)
        else:
            for key, value in values.items():
                setattr(row, key, value)
        await db.commit()
        await db.refresh(row)
        return row
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/payments", response_model=List[schema.PaymentRecordSchema])
async def list_payments(collector_id: str = Query(...), db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(models.PaymentRecord)
        .where(models.PaymentRecord.collector_id == collector_id)
        .order_by(models.PaymentRecord.recorded_at.desc())
    )
    return result.scalars().all()

@app.post("/manifests/checkpoint", response_model=schema.Form6ManifestSchema)
async def create_manifest(manifest: schema.Form6ManifestSchema, db: AsyncSession = Depends(get_db)):
    try:
        # Save each staged signature against the same manifest ID. The legacy
        # manifests table depends on a finalized transaction row, which does
        # not exist yet while the dispatch/transit/delivery flow is underway.
        ledger_row = await db.get(
            models.Form6CheckpointLedger, manifest.manifest_id
        )
        payload = manifest.model_dump(mode="json", by_alias=True)
        if ledger_row is None:
            ledger_row = models.Form6CheckpointLedger(
                manifest_id=manifest.manifest_id,
                payload=payload,
                updated_at=datetime.now(timezone.utc),
            )
            db.add(ledger_row)
        else:
            ledger_row.payload = payload
            ledger_row.updated_at = datetime.now(timezone.utc)
        await db.commit()
        return manifest
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/manifests/{manifest_id}")
async def get_form6_manifest(manifest_id: str, db: AsyncSession = Depends(get_db)):
    """Read a stored transfer record by its unique manifest reference."""
    row = await db.get(models.Form6CheckpointLedger, manifest_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Manifest not found")
    return row.payload

@app.get("/price-dataset")
async def get_price_dataset(
    material_category: Optional[str] = Query(None),
    location: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    """Return observed field prices, grouped with ranges and basic trends."""
    query = select(models.PriceDatasetEntry).order_by(models.PriceDatasetEntry.date.desc())
    if material_category:
        query = query.where(models.PriceDatasetEntry.material_category == material_category)
    if location:
        query = query.where(models.PriceDatasetEntry.location.ilike(f"%{location}%"))
    rows = (await db.execute(query)).scalars().all()

    groups: dict[tuple, list] = {}
    for row in rows:
        key = (row.material_category, row.material_sub_category, row.location, row.unit)
        groups.setdefault(key, []).append(row)

    response = []
    for (category, subcategory, place, unit), entries in groups.items():
        entries.sort(key=lambda item: item.date)
        buys = [item.buying_price for item in entries]
        sells = [item.selling_price for item in entries]
        latest = entries[-1]
        previous = entries[-2] if len(entries) > 1 else None
        trend = None
        if previous and previous.buying_price:
            trend = round((latest.buying_price - previous.buying_price) / previous.buying_price * 100, 2)
        response.append({
            "id": latest.id,
            "materialCategory": category,
            "materialSubCategory": subcategory,
            "location": place,
            "date": latest.date.isoformat(),
            "buyingPrice": latest.buying_price,
            "sellingPrice": latest.selling_price,
            "unit": unit,
            "recyclerId": latest.recycler_id,
            "marketRangeLow": min(buys),
            "marketRangeHigh": max(buys),
            "offeredRangeLow": min(sells),
            "offeredRangeHigh": max(sells),
            "trendPercent": trend,
            "observations": len(entries),
            "source": "Recorded field transactions",
        })
    return response

@app.post("/price-dataset")
async def record_price_dataset_entry(
    entry: schema.PriceDatasetEntrySchema,
    db: AsyncSession = Depends(get_db),
):
    """Record a field-observed buying price and recycler/aggregator offer."""
    try:
        values = entry.model_dump(exclude_unset=True, by_alias=False)
        row = models.PriceDatasetEntry(**values)
        db.add(row)
        await db.commit()
        await db.refresh(row)
        return schema.PriceDatasetEntrySchema.model_validate(row).model_dump(by_alias=True)
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/prices")
async def get_prices():
    """Live global raw-metal benchmarks; these are not local scrap offers."""
    try:
        return await get_live_metal_benchmarks()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Live metal-price provider unavailable: {str(e)}")

@app.get("/news")
async def get_news():
    """Recent India-focused recycling coverage from the live GDELT API."""
    try:
        return await get_live_news()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Live news provider unavailable: {str(e)}")


@app.get("/recycling-points/nearby")
async def get_nearby_recycling_points_route(
    lat: float = Query(..., ge=-90, le=90),
    lng: float = Query(..., ge=-180, le=180),
    radius_km: float = Query(20.0, gt=0, le=50),
):
    """Nearby OpenStreetMap recycling listings; authorization is not verified."""
    try:
        return await get_nearby_recycling_points(lat, lng, radius_km)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"OpenStreetMap lookup failed: {str(e)}")

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
    if _engine is None:
        raise HTTPException(
            status_code=503,
            detail="Image classification is disabled on this free-tier deployment.",
        )
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
