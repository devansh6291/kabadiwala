/// One collector's contribution to a pool.
class LotPoolEntry {
  String lotId;
  String
      collectorLabel; // display name/id — real multi-collector pooling is a backend concern
  double weightKg;

  LotPoolEntry({
    required this.lotId,
    required this.collectorLabel,
    required this.weightKg,
  });
}

enum PoolStatus { collecting, readyForPickup, dispatched }

/// A pool of lots of the same category, aggregated toward one recycler's
/// minimum vehicle capacity (idea doc section 3.3). Real cross-device
/// pooling belongs on the backend (it has to see every collector's
/// lots) — this local model exists so the UI can show pool progress and
/// so the Form-6 custody flow has something concrete to sign against.
///
/// TODO(backend-team): once the Node.js pooling API exists, replace the
/// local mock contributions in [PoolStore] with the real synced pool.
class Pool {
  String id;
  String category;
  String recyclerId;
  double thresholdKg;
  List<LotPoolEntry> entries;
  PoolStatus status;
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
