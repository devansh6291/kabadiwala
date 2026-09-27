class Recycler {
  final String recyclerId;
  final String name;
  final double facilityLat;
  final double facilityLng;
  final List<String> materialsAccepted;
  final String? authorizationNumber;
  final String? authorizationSource;
  final String? authorizationSourceUrl;
  final String? authorizationValidUntil;
  final String authorizationStatus; // "authorized" / "pending" / "unauthorized"
  final String contactDetails;
  final Map<String, double> offeredRates; // category -> ₹/kg
  final String pickupAvailability; // "same_day" / "scheduled" / "none"
  final double? distanceKm;

  /// Minimum lot weight (kg) this recycler requires before dispatching a vehicle.
  final double minVehicleCapacityKg;

  final bool hasOwnLogistics;

  /// True for large-Kabadiwala storage points (custody-only points).
  final bool isStorageOnly;

  /// ₹ per item, per week — only meaningful when [isStorageOnly] is true.
  final double? storageRatePerItemPerWeek;

  /// True when this profile is a local sample used for demonstrations.
  final bool isSampleData;

  const Recycler({
    required this.recyclerId,
    required this.name,
    required this.facilityLat,
    required this.facilityLng,
    required this.materialsAccepted,
    this.authorizationNumber,
    this.authorizationSource,
    this.authorizationSourceUrl,
    this.authorizationValidUntil,
    required this.authorizationStatus,
    required this.contactDetails,
    required this.offeredRates,
    required this.pickupAvailability,
    this.distanceKm,
    required this.minVehicleCapacityKg,
    required this.hasOwnLogistics,
    this.isStorageOnly = false,
    this.storageRatePerItemPerWeek,
    this.isSampleData = false,
  });

  factory Recycler.fromJson(Map<String, dynamic> json) {
    final rawRates = json['offered_rates'] ?? json['offeredRates'] ?? {};
    final Map<String, double> rates = {};
    if (rawRates is Map) {
      rawRates.forEach((key, value) {
        rates[key.toString()] = (value as num).toDouble();
      });
    }

    final rawMaterials =
        json['materials_accepted'] ?? json['materialsAccepted'] ?? [];
    final List<String> materials =
        (rawMaterials as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            [];

    return Recycler(
      recyclerId: (json['recycler_id'] ?? json['recyclerId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      facilityLat: ((json['facility_lat'] ?? json['facilityLat'] ?? 0.0) as num)
          .toDouble(),
      facilityLng: ((json['facility_lng'] ?? json['facilityLng'] ?? 0.0) as num)
          .toDouble(),
      materialsAccepted: materials,
      authorizationNumber:
          json['authorization_number'] ?? json['authorizationNumber'],
      authorizationSource: json['authorizationSource']?.toString(),
      authorizationSourceUrl: json['authorizationSourceUrl']?.toString(),
      authorizationValidUntil: json['authorizationValidUntil']?.toString(),
      authorizationStatus: (json['authorization_status'] ??
              json['authorizationStatus'] ??
              'authorized')
          .toString(),
      contactDetails:
          (json['contact_details'] ?? json['contactDetails'] ?? '').toString(),
      offeredRates: rates,
      pickupAvailability: (json['pickup_availability'] ??
              json['pickupAvailability'] ??
              'scheduled')
          .toString(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      minVehicleCapacityKg: ((json['min_vehicle_capacity_kg'] ??
              json['minVehicleCapacityKg'] ??
              0.0) as num)
          .toDouble(),
      hasOwnLogistics: (json['has_own_logistics'] ??
              json['hasOwnLogistics'] ??
              false) ==
          true,
      isStorageOnly:
          (json['is_storage_only'] ?? json['isStorageOnly'] ?? false) == true,
      storageRatePerItemPerWeek: (json['storage_rate_per_item_week'] ??
              json['storageRatePerItemPerWeek'] as num?)
          ?.toDouble(),
      isSampleData: json['is_sample_data'] == true || json['isSampleData'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'recycler_id': recyclerId,
        'name': name,
        'facility_lat': facilityLat,
        'facility_lng': facilityLng,
        'materials_accepted': materialsAccepted,
        'authorization_number': authorizationNumber,
        'authorization_source': authorizationSource,
        'authorization_source_url': authorizationSourceUrl,
        'authorization_valid_until': authorizationValidUntil,
        'authorization_status': authorizationStatus,
        'contact_details': contactDetails,
        'offered_rates': offeredRates,
        'pickup_availability': pickupAvailability,
        'distance_km': distanceKm,
        'min_vehicle_capacity_kg': minVehicleCapacityKg,
        'has_own_logistics': hasOwnLogistics,
        'is_storage_only': isStorageOnly,
        'storage_rate_per_item_week': storageRatePerItemPerWeek,
        'is_sample_data': isSampleData,
      };
}
