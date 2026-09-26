from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List, Dict, Any
from datetime import datetime

class LotSchema(BaseModel):
    id: str = Field(..., alias="lot_id")
    category: str
    sub_category: Optional[str] = Field(None, alias="subCategory")
    approx_weight_kg: float = Field(..., alias="approxWeightKg")
    photo_paths: Optional[List[str]] = Field(None, alias="photoPaths", validation_alias="photo_urls")
    estimated_value: Optional[float] = Field(None, alias="estimatedValue")
    quoted_price: Optional[float] = Field(None, alias="quotedPrice")
    final_sale_value: Optional[float] = Field(None, alias="finalSaleValue")
    created_at: datetime = Field(..., alias="createdAt")
    latitude: Optional[float] = Field(None, validation_alias="collection_latitude")
    longitude: Optional[float] = Field(None, validation_alias="collection_longitude")
    sync_status: str = Field(default="pending", alias="syncStatus")
    recycler_id: Optional[str] = Field(None, alias="recyclerId")
    collector_id: Optional[str] = Field(None, alias="collectorId")
    model_config = ConfigDict(populate_by_name=True, from_attributes=True, serialize_by_alias=True, extra="allow")

class CollectorSchema(BaseModel):
    collector_id: str = Field(..., alias="collectorId")
    name: str = ""
    age: Optional[int] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    preferred_language: str = Field("hi", alias="preferredLanguage")
    operating_location: str = Field("", alias="operatingLocation")
    is_onboarded: bool = Field(False, alias="isOnboarded")
    phone_number: str = Field(..., alias="phoneNumber")
    total_earnings: float = Field(0.0, alias="totalEarnings")
    has_own_logistics: bool = Field(False, alias="hasOwnLogistics")
    transaction_history_ids: Optional[List[str]] = Field(default_factory=list, alias="transactionHistoryIds")
    model_config = ConfigDict(populate_by_name=True, from_attributes=True, serialize_by_alias=True, extra="allow")

class RecyclerSchema(BaseModel):
    recycler_id: str = Field(..., alias="recyclerId")
    name: str
    facility_location_lat: float = Field(..., alias="facilityLat")
    facility_location_lng: float = Field(..., alias="facilityLng")
    materials_accepted: Any = Field(default_factory=list, alias="materialsAccepted")
    authorization_number: Optional[str] = Field(None, alias="authorizationNumber")
    authorization_status: str = Field("pending", alias="authorizationStatus")
    contact_details: str = Field("", alias="contactDetails")
    offered_rates: Any = Field(default_factory=dict, alias="offeredRates")
    pickup_availability: str = Field("", alias="pickupAvailability")
    service_area_radius_km: float = Field(15.0, alias="serviceAreaRadiusKm")
    has_own_logistics: bool = Field(False, alias="hasOwnLogistics")
    min_vehicle_capacity_kg: float = Field(0.0, alias="minVehicleCapacityKg")
    is_storage_only: bool = Field(False, alias="isStorageOnly")
    storage_rate_per_item_week: Optional[float] = Field(None, alias="storageRatePerItemWeek")
    model_config = ConfigDict(populate_by_name=True, from_attributes=True, serialize_by_alias=True, extra="allow")

class StorageHostSchema(BaseModel):
    host_id: str = Field(..., alias="hostId")
    name: str
    latitude: float
    longitude: float
    weekly_rate_per_item: float = Field(..., alias="weeklyRatePerItem")
    available_capacity: int = Field(..., alias="availableCapacity")
    rating: float = 0.0
    model_config = ConfigDict(populate_by_name=True, from_attributes=True, serialize_by_alias=True, extra="allow")

class LotPoolEntrySchema(BaseModel):
    lot_id: str = Field(..., alias="lotId")
    collector_label: str = Field(..., alias="collectorLabel")
    weight_kg: float = Field(..., alias="weightKg")
    model_config = ConfigDict(populate_by_name=True, from_attributes=True, serialize_by_alias=True, extra="allow")

class PoolSchema(BaseModel):
    id: str = Field(..., alias="poolId")
    category: str = Field(..., alias="materialCategory")
    recycler_id: str = Field(..., alias="recyclerId")
    threshold_kg: float = Field(..., alias="targetThresholdKg")
    current_weight_kg: Optional[float] = Field(None, alias="currentWeightKg")
    status: str
    storage_kabadiwala_id: Optional[str] = Field(None, alias="storageHostId")
    entries: List[LotPoolEntrySchema] = Field(default_factory=list)
    created_at: datetime = Field(..., alias="createdAt")
    model_config = ConfigDict(populate_by_name=True, from_attributes=True, serialize_by_alias=True, extra="allow")

class TransactionSchema(BaseModel):
    transaction_id: str = Field(..., alias="transactionId")
    lot_id: str = Field(..., alias="lotId")
    collector_id: str = Field(..., alias="collectorId")
    recycler_id: str = Field(..., alias="recyclerId")
    quoted_price: float = Field(..., alias="quotedPrice")
    final_price: float = Field(..., alias="finalPrice")
    payment_status: str = Field("unpaid", alias="paymentStatus")
    transaction_status: str = Field("created", alias="transactionStatus")
    model_config = ConfigDict(populate_by_name=True, from_attributes=True, serialize_by_alias=True, extra="allow")

class Form6ManifestSchema(BaseModel):
    manifest_id: str = Field(..., alias="manifestId")
    sender_name: str = Field(..., alias="senderName")
    sender_phone: str = Field(..., alias="senderPhone")
    transporter_id: str = Field(..., alias="transporterId")
    transporter_name: str = Field(..., alias="transporterName")
    material_type: str = Field(..., alias="materialType")
    quantity: float
    destination_recycler_id: str = Field(..., alias="destinationRecyclerId")
    checkpoint_dispatch: Optional[dict] = Field(None, alias="checkpointDispatch")
    checkpoint_transit: Optional[dict] = Field(None, alias="checkpointTransit")
    checkpoint_delivery: Optional[dict] = Field(None, alias="checkpointDelivery")
    chain_hash: Optional[str] = Field(None, alias="chainHash")
    model_config = ConfigDict(populate_by_name=True, from_attributes=True, serialize_by_alias=True, extra="allow")

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
    model_config = ConfigDict(populate_by_name=True, from_attributes=True, serialize_by_alias=True, extra="allow")

class NewsItemSchema(BaseModel):
    id: Optional[str] = None
    title: str
    source: str
    date: datetime
    snippet: str
    url: Optional[str] = None
    model_config = ConfigDict(populate_by_name=True, from_attributes=True, serialize_by_alias=True, extra="allow")

class ContributionSchema(BaseModel):
    lot_id: str = Field(..., alias="lotId")
    weight_kg: float = Field(..., alias="weightKg")
    collector_label: str = Field("You", alias="collectorLabel")
    model_config = ConfigDict(populate_by_name=True, from_attributes=True, serialize_by_alias=True, extra="allow")