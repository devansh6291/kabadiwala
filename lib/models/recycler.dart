class Recycler {
  final String recyclerId;
  final String name;
  final double facilityLat;
  final double facilityLng;
  final List<String> materialsAccepted;
  final String? authorizationNumber;
  final String authorizationStatus; // "authorized" / "pending" / "unauthorized"
  final String contactDetails;
  final Map<String, double> offeredRates; // category → ₹/kg
  final String pickupAvailability; // "same_day" / "scheduled" / "none"

  /// Minimum lot weight (kg) this recycler requires before dispatching a
  /// vehicle. A single lot below this threshold gets pooled with others.
  final double minVehicleCapacityKg;

  final bool hasOwnLogistics;

  /// True for large-Kabadiwala storage points (idea doc section 3.3/4) —
  /// these never appear in a buying match, only in the storage fallback.
  final bool isStorageOnly;

  /// ₹ per item, per week — only meaningful when [isStorageOnly] is true.
  final double? storageRatePerItemPerWeek;

  const Recycler({
    required this.recyclerId,
    required this.name,
    required this.facilityLat,
    required this.facilityLng,
    required this.materialsAccepted,
    this.authorizationNumber,
    required this.authorizationStatus,
    required this.contactDetails,
    required this.offeredRates,
    required this.pickupAvailability,
    required this.minVehicleCapacityKg,
    required this.hasOwnLogistics,
    this.isStorageOnly = false,
    this.storageRatePerItemPerWeek,
  });
}
