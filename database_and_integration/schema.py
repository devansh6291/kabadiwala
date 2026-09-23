from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List, Dict
from datetime import datetime

# 1. LOT
class LotSchema(BaseModel):
    id: str
    category: str
    sub_category: Optional[str] = Field(None, alias="subCategory")
    approx_weight_kg: float = Field(..., alias="approxWeightKg")
    photo_paths: Optional[List[str]] = Field(None, alias="photoPaths")
    estimated_value: Optional[float] = Field(None, alias="estimatedValue")
    quoted_price: Optional[float] = Field(None, alias="quotedPrice")
    final_sale_value: Optional[float] = Field(None, alias="finalSaleValue")
    created_at: datetime = Field(..., alias="createdAt")
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    sync_status: str = Field(default="pending", alias="syncStatus")
    recycler_id: Optional[str] = Field(None, alias="recyclerId")
    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

# 2. COLLECTOR (Flutter sends snake_case)
class CollectorSchema(BaseModel):
    collector_id: str
    name: str = ""
    age: Optional[int] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    preferred_language: str = "hi"
    operating_location: str = ""
    is_onboarded: bool = False
    phone_number: str
    total_earnings: float = 0.0
    has_own_logistics: bool = False
    transaction_history_ids: Optional[List[str]] = Field(default_factory=list)
    model_config = ConfigDict(from_attributes=True)

# 3. RECYCLER (Flutter sends snake_case)
class RecyclerSchema(BaseModel):
    recycler_id: str
    name: str
    facility_location_lat: float = Field(alias="facility_lat")
    facility_location_lng: float = Field(alias="facility_lng")
    materials_accepted: List[str]
    authorization_number: Optional[str] = None
    authorization_status: str = "pending"
    contact_details: str
    offered_rates: Optional[Dict[str, float]] = None
    pickup_availability: str
    service_area_radius_km: float = 15.0 
    has_own_logistics: bool = False
    min_vehicle_capacity_kg: float = 0.0
    is_storage_only: bool = False
    storage_rate_per_item_week: Optional[float] = None
    
    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

# 4. STORAGE HOST
class StorageHostSchema(BaseModel):
    host_id: str
    name: str
    latitude: float
    longitude: float
    weekly_rate_per_item: float
    available_capacity: int
    rating: float = 0.0
    model_config = ConfigDict(from_attributes=True)

# 5. POOL & ENTRIES
class LotPoolEntrySchema(BaseModel):
    lot_id: str
    collector_label: str
    weight_kg: float
    model_config = ConfigDict(from_attributes=True)

class PoolSchema(BaseModel):
    id: str = Field(..., alias="pool_id")
    category: str = Field(..., alias="material_category")
    recycler_id: str
    threshold_kg: float = Field(..., alias="target_threshold_kg")
    current_weight_kg: Optional[float] = None # Flutter sends this, but we ignore it for DB insertion
    status: str
    storage_kabadiwala_id: Optional[str] = Field(None, alias="storage_host_id")
    entries: List[LotPoolEntrySchema] = Field(default_factory=list) # Catches the nested list
    created_at: datetime
    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

# 6. TRANSACTIONS & MANIFESTS
class TransactionSchema(BaseModel):
    transaction_id: str
    lot_id: str
    collector_id: str
    recycler_id: str
    quoted_price: float
    final_price: float
    payment_status: str = "unpaid"
    transaction_status: str = "created"
    collection_location_lat: Optional[float] = None
    collection_location_lng: Optional[float] = None
    handover_location_lat: Optional[float] = None
    handover_location_lng: Optional[float] = None
    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

class Form6ManifestSchema(BaseModel):
    manifest_id: str
    sender_name: str
    sender_address: Optional[str] = None
    sender_phone: str
    sender_authorization_number: Optional[str] = None
    transporter_id: str
    transporter_name: str
    material_type: str
    quantity: float
    destination_recycler_id: str
    checkpoint_dispatch: Optional[dict] = None
    checkpoint_transit: Optional[dict] = None
    checkpoint_delivery: Optional[dict] = None
    chain_hash: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)

# 7. PRICE DATASET & NEWS
class PriceDatasetEntrySchema(BaseModel):
    id: Optional[str] = None
    material_category: str = Field(..., alias="materialCategory")
    material_sub_category: Optional[str] = Field(None, alias="materialSubCategory")
    location: str
    date: datetime
    buying_price: float = Field(..., alias="buyingPrice")
    selling_price: float = Field(..., alias="sellingPrice")
    unit: str = "per_kg"
    recycler_id: Optional[str] = Field(None, alias="recyclerId")
    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

class NewsItemSchema(BaseModel):
    id: Optional[str] = None
    title: str
    source: str
    date: datetime
    snippet: str
    url: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)

class ContributionSchema(BaseModel):
    lot_id: str
    weight_kg: float
    collector_label: str