import 'pool.dart';

/// In-memory pool registry for this device.
///
/// Pooling is fundamentally a multi-collector, server-side concept — the
/// backend has to see every nearby collector's lots to form a real pool.
/// Until that Node.js service exists, this store simulates it locally:
/// each new pool is seeded with a couple of plausible "nearby collector"
/// contributions so the pooling UI has something realistic to show
/// during demos. Swap this whole class for API calls once the backend
/// pooling endpoint is ready — [Pool] and [LotPoolEntry] can stay as-is.
class PoolStore {
  static final List<Pool> _pools = [];

  /// Finds an open (collecting) pool for this recycler+category, or
  /// creates one — seeded with mock nearby-collector contributions.
  static Pool getOrCreatePool({
    required String recyclerId,
    required String category,
    required double thresholdKg,
  }) {
    final existing = _pools.firstWhere(
      (p) =>
          p.recyclerId == recyclerId &&
          p.category == category &&
          p.status == PoolStatus.collecting,
      orElse: () => _createSeededPool(
        recyclerId: recyclerId,
        category: category,
        thresholdKg: thresholdKg,
      ),
    );
    if (!_pools.contains(existing)) {
      _pools.add(existing);
    }
    return existing;
  }

  static Pool _createSeededPool({
    required String recyclerId,
    required String category,
    required double thresholdKg,
  }) {
    // Seed with mock nearby-collector weight so the threshold feels
    // reachable in a demo instead of always starting from zero.
    final seedWeight = (thresholdKg * 0.35).clamp(0, thresholdKg * 0.6);
    return Pool(
      id: 'pool_${recyclerId}_${category}_${DateTime.now().millisecondsSinceEpoch}',
      category: category,
      recyclerId: recyclerId,
      thresholdKg: thresholdKg,
      entries: [
        LotPoolEntry(
          lotId: 'seed_1',
          collectorLabel: 'Nearby collector (Rampur beat)',
          weightKg: double.parse(seedWeight.toStringAsFixed(1)),
        ),
      ],
      createdAt: DateTime.now(),
    );
  }

  static void addLotToPool(Pool pool,
      {required String lotId, required double weightKg}) {
    pool.entries.add(
      LotPoolEntry(lotId: lotId, collectorLabel: 'You', weightKg: weightKg),
    );
    if (pool.isThresholdMet && pool.status == PoolStatus.collecting) {
      pool.status = PoolStatus.readyForPickup;
    }
  }

  static void markStorageAssigned(Pool pool, String storageKabadiwalaId) {
    pool.storageKabadiwalaId = storageKabadiwalaId;
  }

  static List<Pool> getAllPools() => List.unmodifiable(_pools);
}
