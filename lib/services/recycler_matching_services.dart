import '../data/recycler_mock_data.dart';
import '../models/lot.dart';
import '../models/pool.dart';
import '../models/pool_store.dart';
import '../models/recycler.dart';

enum RoutingOutcome {
  /// Lot alone already meets a recycler's minimum vehicle capacity.
  directDispatch,

  /// Pool exists but hasn't reached the recycler's threshold yet.
  pooling,

  /// Pool just reached (or already met) the threshold — ready for pickup.
  poolReadyForPickup,

  /// Collector has no storage; material routed to a large Kabadiwala to
  /// hold until the pool completes (idea doc section 3.3 / section 4).
  routedToStorage,

  /// No authorized recycler currently accepts this category.
  noRecyclerAvailable,
}

class RoutingResult {
  final RoutingOutcome outcome;
  final Recycler? recycler;
  final Pool? pool;
  final Recycler? storageKabadiwala;

  const RoutingResult({
    required this.outcome,
    this.recycler,
    this.pool,
    this.storageKabadiwala,
  });
}

/// Implements the idea doc's dual routing + pooling + storage-fallback
/// logic (sections 3.2–3.3). Plastics vs. e-waste is just "which
/// recyclers accept this category" here — [RecyclerMockData] already
/// separates plastic-manufacturer entries from authorized e-waste
/// recyclers by their `materialsAccepted` lists.
///
/// TODO(backend-team): this whole service is a client-side stand-in for
/// the real Node.js matching/pooling engine described in the idea doc's
/// architecture section. Swap the mock data + local [PoolStore] for real
/// API calls; keep the same [RoutingResult] shape so the UI doesn't need
/// to change.
class RecyclerMatchingService {
  /// [hasStorage] — whether this collector (or their local aggregator)
  /// can hold pooled material until the vehicle-capacity threshold is
  /// met. When false and pooling is needed, the lot is routed to a
  /// storage-only Kabadiwala instead.
  static RoutingResult route(Lot lot, {required bool hasStorage}) {
    final candidates = RecyclerMockData.forCategory(lot.category);
    if (candidates.isEmpty) {
      return const RoutingResult(outcome: RoutingOutcome.noRecyclerAvailable);
    }

    // Pick the best offered rate for this category among matching recyclers.
    candidates.sort(
      (a, b) => (b.offeredRates[lot.category] ?? 0)
          .compareTo(a.offeredRates[lot.category] ?? 0),
    );
    final bestRecycler = candidates.first;

    if (lot.approxWeightKg >= bestRecycler.minVehicleCapacityKg) {
      return RoutingResult(
        outcome: RoutingOutcome.directDispatch,
        recycler: bestRecycler,
      );
    }

    final pool = PoolStore.getOrCreatePool(
      recyclerId: bestRecycler.recyclerId,
      category: lot.category,
      thresholdKg: bestRecycler.minVehicleCapacityKg,
    );
    PoolStore.addLotToPool(pool, lotId: lot.id, weightKg: lot.approxWeightKg);

    if (!hasStorage) {
      final storagePoints = RecyclerMockData.storagePointsFor(lot.category);
      final storageKabadiwala =
          storagePoints.isNotEmpty ? storagePoints.first : null;
      if (storageKabadiwala != null) {
        PoolStore.markStorageAssigned(pool, storageKabadiwala.recyclerId);
        return RoutingResult(
          outcome: RoutingOutcome.routedToStorage,
          recycler: bestRecycler,
          pool: pool,
          storageKabadiwala: storageKabadiwala,
        );
      }
      // No storage point registered for this category — fall through to
      // normal pooling; the UI should make clear storage wasn't found.
    }

    return RoutingResult(
      outcome: pool.isThresholdMet
          ? RoutingOutcome.poolReadyForPickup
          : RoutingOutcome.pooling,
      recycler: bestRecycler,
      pool: pool,
    );
  }
}
