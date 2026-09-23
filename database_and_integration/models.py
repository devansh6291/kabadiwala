from sqlalchemy import Column, String, CHAR, Float, Boolean, DateTime, JSON, ForeignKey, Integer
from sqlalchemy.orm import declarative_base
import uuid
from datetime import datetime, timezone

Base = declarative_base()

class Lot(Base):
    __tablename__ = "lots"
    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    category = Column(String(50), nullable=False)
    sub_category = Column(String(50), nullable=True)
    approx_weight_kg = Column(Float, nullable=False)
    photo_paths = Column(JSON, nullable=True)
    estimated_value = Column(Float, nullable=True)
    quoted_price = Column(Float, nullable=True)
    final_sale_value = Column(Float, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    sync_status = Column(String(50), default="pending")
    recycler_id = Column(CHAR(36), ForeignKey("recyclers.recycler_id"), nullable=True)

class Collector(Base):
    __tablename__ = "collectors"
    collector_id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    transaction_history_ids = Column(JSON, default=list)
    name = Column(String(50), default='')
    age = Column(Integer, nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    preferred_language = Column(String(50), default='hi')
    operating_location = Column(String(50), default='')
    is_onboarded = Column(Boolean, default=False)
    phone_number = Column(String(20), unique=True, nullable=False)
    total_earnings = Column(Float, default=0.0)
    has_own_logistics = Column(Boolean, default=False)

class Recycler(Base):
    __tablename__ = "recyclers"
    recycler_id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(100), nullable=False)
    facility_location_lat = Column(Float, nullable=False)
    facility_location_lng = Column(Float, nullable=False)
    materials_accepted = Column(JSON, nullable=False)
    authorization_number = Column(String(100), nullable=True)
    authorization_status = Column(String(50), default="pending")
    contact_details = Column(String(100), nullable=False)
    offered_rates = Column(JSON, nullable=True)
    pickup_availability = Column(String(50), nullable=False)
    service_area_radius_km = Column(Float, nullable=False, default=15.0)
    has_own_logistics = Column(Boolean, default=False)
    min_vehicle_capacity_kg = Column(Float, default=0.0)
    is_storage_only = Column(Boolean, default=False)
    storage_rate_per_item_week = Column(Float, nullable=True)

class StorageHost(Base):
    __tablename__ = "storage_hosts"
    host_id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(50), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    weekly_rate_per_item = Column(Float, nullable=False)
    available_capacity = Column(Integer, nullable=False)
    rating = Column(Float, default=0.0)

class Pool(Base):
    __tablename__ = "pools"
    id = Column(String(255), primary_key=True)
    category = Column(String(50), nullable=False)
    recycler_id = Column(CHAR(36), ForeignKey("recyclers.recycler_id"), nullable=False)
    threshold_kg = Column(Float, nullable=False)
    status = Column(String(50), default="collecting")
    storage_kabadiwala_id = Column(CHAR(36), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

class LotPoolEntry(Base):
    __tablename__ = "lot_pool_entries"
    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    pool_id = Column(String(255), ForeignKey("pools.id"), nullable=False)
    lot_id = Column(CHAR(36), ForeignKey("lots.id"), nullable=False)
    collector_label = Column(String(100), nullable=False)
    weight_kg = Column(Float, nullable=False)

class Transaction(Base):
    __tablename__ = "transactions"
    transaction_id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    lot_id = Column(CHAR(36), ForeignKey("lots.id"), nullable=False)
    collector_id = Column(CHAR(36), ForeignKey("collectors.collector_id"), nullable=False)
    recycler_id = Column(CHAR(36), ForeignKey("recyclers.recycler_id"), nullable=False)
    quoted_price = Column(Float, nullable=False)
    final_price = Column(Float, nullable=False)
    payment_status = Column(String(50), default="unpaid")
    transaction_status = Column(String(50), default="created")
    collection_location_lat = Column(Float, nullable=True)
    collection_location_lng = Column(Float, nullable=True)
    handover_location_lat = Column(Float, nullable=True) 
    handover_location_lng = Column(Float, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    closed_at = Column(DateTime, nullable=True)

class DigitalForm6Manifest(Base):
    __tablename__ = "manifests"
    manifest_id = Column(CHAR(36), ForeignKey("transactions.transaction_id"), primary_key=True)
    sender_name = Column(String(100), nullable=False)
    sender_address = Column(String(100), nullable=True)
    sender_phone = Column(String(100), nullable=False)
    sender_authorization_number = Column(String(100), nullable=True)
    transporter_id = Column(String(100), nullable=False)
    transporter_name = Column(String(100), nullable=False)
    material_type = Column(String(50), nullable=False)
    quantity = Column(Float, nullable=False)
    destination_recycler_id = Column(CHAR(36), ForeignKey("recyclers.recycler_id"), nullable=False)
    checkpoint_dispatch = Column(JSON, nullable=True)
    checkpoint_transit = Column(JSON, nullable=True)
    checkpoint_delivery = Column(JSON, nullable=True)
    chain_hash = Column(String(255), nullable=True)

class PriceDatasetEntry(Base):
    __tablename__ = "price_dataset_entries"
    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    material_category = Column(String(50), nullable=False)
    material_sub_category = Column(String(50), nullable=True)
    location = Column(String(100), nullable=False)
    date = Column(DateTime, nullable=False)
    buying_price = Column(Float, nullable=False)
    selling_price = Column(Float, nullable=False)
    unit = Column(String(50), default="per_kg")
    recycler_id = Column(CHAR(36), ForeignKey("recyclers.recycler_id"), nullable=True)

class NewsItem(Base):
    __tablename__ = "news_items"
    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String(255), nullable=False)
    source = Column(String(100), nullable=False)
    date = Column(DateTime, nullable=False)
    snippet = Column(String(1000), nullable=False)
    url = Column(String(500), nullable=True)