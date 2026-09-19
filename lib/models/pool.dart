class LotPoolEntry {
  String lotId;
  String collectorLabel;
  double weightKg;

  LotPoolEntry({
    required this.lotId,
    required this.collectorLabel,
    required this.weightKg,
  });
}

enum PoolStatus { collecting, storageNeeded, readyForPickup, dispatched }

class Pool {
  String id;
  String category;
  String recyclerId;
  double thresholdKg;
  List<LotPoolEntry> entries;
  PoolStatus status;

  /// Set when at least one contributing collector has no storage of
  /// their own and is routed to a StorageHost (see storage_host.dart)
  /// to hold their item(s) until the pool is ready.
  String? storageKabadiwalaId;

  DateTime createdAt;

  Pool({
    required this.id,
    required this.category,
    required this.recyclerId,
    required this.thresholdKg,
    required this.entries,
    this.status = PoolStatus.collecting,
    this.storageKabadiwalaId,
    required this.createdAt,
  });

  double get totalWeightKg => entries.fold(0.0, (sum, e) => sum + e.weightKg);
  bool get isThresholdMet => totalWeightKg >= thresholdKg;
  double get remainingKg =>
      (thresholdKg - totalWeightKg).clamp(0, thresholdKg).toDouble();
}
