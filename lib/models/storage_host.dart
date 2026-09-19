/// A larger kabadiwala offering paid custody/storage for pooled items
/// until a pool's threshold is reached, per the idea doc's custody
/// mechanism. Distinct from a Recycler — this party never buys the
/// material, only holds it safely for a fee.
class StorageHost {
  final String hostId;
  final String name;
  final double latitude;
  final double longitude;

  /// ₹ per item per week — typically 20-50 as agreed with the platform.
  final double weeklyRatePerItem;

  final int availableCapacity;
  final double rating; // built from past custody completion history

  const StorageHost({
    required this.hostId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.weeklyRatePerItem,
    required this.availableCapacity,
    required this.rating,
  });
}
