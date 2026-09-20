class LotPoolEntry {
  String lotId;
  String collectorLabel;
  double weightKg;

  LotPoolEntry({
    required this.lotId,
    required this.collectorLabel,
    required this.weightKg,
  });

  factory LotPoolEntry.fromJson(Map<String, dynamic> json) => LotPoolEntry(
        lotId: (json['lot_id'] ?? json['lotId'] ?? '').toString(),
        collectorLabel:
            (json['collector_label'] ?? json['collectorLabel'] ?? 'Collector')
                .toString(),
        weightKg:
            ((json['weight_kg'] ?? json['weightKg'] ?? 0.0) as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'lot_id': lotId,
        'collector_label': collectorLabel,
        'weight_kg': weightKg,
      };
}

enum PoolStatus { collecting, storageNeeded, readyForPickup, dispatched }

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

  factory Pool.fromJson(Map<String, dynamic> json) {
    final rawEntries = (json['entries'] as List<dynamic>?) ?? [];
    final parsedEntries = rawEntries
        .map((e) => LotPoolEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final statusStr = (json['status'] ?? 'collecting').toString();
    PoolStatus parsedStatus = PoolStatus.collecting;
    if (statusStr == 'storageNeeded' || statusStr == 'storage_assigned') {
      parsedStatus = PoolStatus.storageNeeded;
    } else if (statusStr == 'readyForPickup' ||
        statusStr == 'ready_for_pickup') {
      parsedStatus = PoolStatus.readyForPickup;
    } else if (statusStr == 'dispatched') {
      parsedStatus = PoolStatus.dispatched;
    }

    DateTime parsedDate;
    try {
      parsedDate =
          DateTime.parse(json['created_at'] ?? json['createdAt'] ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return Pool(
      id: (json['pool_id'] ?? json['id'] ?? '').toString(),
      category:
          (json['category'] ?? json['material_category'] ?? '').toString(),
      recyclerId: (json['recycler_id'] ?? json['recyclerId'] ?? '').toString(),
      thresholdKg:
          ((json['threshold_kg'] ?? json['target_threshold_kg'] ?? 50.0) as num)
              .toDouble(),
      entries: parsedEntries,
      status: parsedStatus,
      storageKabadiwalaId:
          json['storage_kabadiwala_id'] ?? json['storage_host_id'],
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'pool_id': id,
        'material_category': category,
        'recycler_id': recyclerId,
        'target_threshold_kg': thresholdKg,
        'current_weight_kg': totalWeightKg,
        'status': status.name,
        'storage_host_id': storageKabadiwalaId,
        'entries': entries.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}
