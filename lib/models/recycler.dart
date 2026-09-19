/// Recycler / Aggregator — matches the data dictionary's Recycler entity,
/// plus two fields needed for pooling/storage that the dictionary doesn't
/// have yet: [minVehicleCapacityKg] (the "50 kg before a vehicle is
/// dispatched" rule from the idea doc) and [isStorageOnly] (marks a large
/// Kabadiwala who only custodies pooled material, never buys/processes it).
class Recycler {
  String recyclerId;
  String name;
  double facilityLat;
  double facilityLng;

  /// Category strings matching Lot.category.
  List<String> materialsAccepted;

  String? authorizationNumber;

  /// "authorized" | "pending" | "unauthorized"
  String authorizationStatus;

  String contactDetails;

  /// Category -> ₹/kg rate.
  Map<String, double> offeredRates;

  /// "same_day" | "scheduled" | "none"
  String pickupAvailability;

  /// Minimum pooled weight before a vehicle is dispatched (idea doc: e.g. 50 kg).
  double minVehicleCapacityKg;

  bool hasOwnLogistics;

  /// True for a large Kabadiwala who custodies pooled e-waste for a paid
  /// weekly rate but is not itself an authorized recycler.
  bool isStorageOnly;

  Recycler({
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
  });
}
