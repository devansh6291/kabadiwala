import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/lot.dart';
import '../models/pool.dart';
import '../models/recycler.dart';
import '../models/storage_host.dart';
import 'api_client.dart';
import 'location_service.dart';

enum RoutingOutcome {
  directDispatch,
  pooling,
  poolReadyForPickup,
  routedToStorage,
  noRecyclerAvailable,
}

class RoutingResult {
  final RoutingOutcome outcome;
  final Recycler? recycler;
  final Pool? pool;
  final StorageHost? storageKabadiwala;

  const RoutingResult({
    required this.outcome,
    this.recycler,
    this.pool,
    this.storageKabadiwala,
  });
}

/// Cloud-connected matching engine hitting the FastAPI + MySQL endpoints.
class RecyclerMatchingService {
  static Future<RoutingResult> route(Lot lot,
      {required bool hasStorage}) async {
    final dio = ApiClient().dio;

    try {
      // 1. Get exact GPS (Fallback to Indore center if denied)
      final pos = await LocationService.getCurrentPosition();
      final lat = pos?.latitude ?? 22.7196;
      final lng = pos?.longitude ?? 75.8577;

      // 2. Query Python backend for nearby authorized recyclers
      final recyclerRes = await dio.get(
        '/recyclers/nearby',
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radius_km': 50.0,
          'material': lot.category,
        },
      );

      final List<dynamic> recyclerData = recyclerRes.data;
      if (recyclerData.isEmpty) {
        return const RoutingResult(outcome: RoutingOutcome.noRecyclerAvailable);
      }

      final candidates = recyclerData.map((j) => Recycler.fromJson(j)).toList();

      // Sort by best offered rate for the material
      candidates.sort((a, b) => (b.offeredRates[lot.category] ?? 0)
          .compareTo(a.offeredRates[lot.category] ?? 0));
      final bestRecycler = candidates.first;

      // 3. Direct Dispatch Check
      if (lot.approxWeightKg >= bestRecycler.minVehicleCapacityKg) {
        return RoutingResult(
            outcome: RoutingOutcome.directDispatch, recycler: bestRecycler);
      }

      // 4. Connect to MySQL Pooling System
      final poolRes = await dio.get(
        '/pools',
        queryParameters: {
          'category': lot.category,
          'recycler_id': bestRecycler.recyclerId,
        },
      );

      List<Pool> activePools = (poolRes.data as List<dynamic>)
          .map((j) => Pool.fromJson(j))
          .where((p) =>
              p.status == PoolStatus.collecting ||
              p.status == PoolStatus.storageNeeded)
          .toList();

      Pool targetPool;
      if (activePools.isNotEmpty) {
        targetPool = activePools.first;
      } else {
        // Create new pool on backend
        final createRes = await dio.post('/pools', data: {
          'pool_id':
              'pool_${bestRecycler.recyclerId}_${DateTime.now().millisecondsSinceEpoch}',
          'material_category': lot.category,
          'recycler_id': bestRecycler.recyclerId,
          'target_threshold_kg': bestRecycler.minVehicleCapacityKg,
          'status': 'collecting',
          'created_at': DateTime.now().toIso8601String(),
        });
        targetPool = Pool.fromJson(createRes.data);
      }

      // Add lot to the cloud pool
      await dio.post('/pools/${targetPool.id}/contribute', data: {
        'lot_id': lot.id,
        'weight_kg': lot.approxWeightKg,
        'collector_label': 'You',
      });

      // Update local object to reflect the contribution instantly for the UI
      targetPool.entries.add(LotPoolEntry(
        lotId: lot.id,
        collectorLabel: 'You',
        weightKg: lot.approxWeightKg,
      ));

      // 5. Custody Storage Fallback
      StorageHost? assignedHost;
      if (!hasStorage) {
        final hostRes = await dio.get(
          '/storage-hosts/nearby',
          queryParameters: {'lat': lat, 'lng': lng, 'radius_km': 20.0},
        );
        final List<dynamic> hostData = hostRes.data;
        if (hostData.isNotEmpty) {
          final json = hostData.first;
          assignedHost = StorageHost(
            hostId: json['host_id']?.toString() ?? '',
            name: json['name']?.toString() ?? '',
            latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
            longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
            weeklyRatePerItem:
                (json['weekly_rate_per_item'] as num?)?.toDouble() ?? 0.0,
            availableCapacity:
                (json['available_capacity'] as num?)?.toInt() ?? 0,
            rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
          );
        }
      }

      if (assignedHost != null) {
        return RoutingResult(
          outcome: RoutingOutcome.routedToStorage,
          recycler: bestRecycler,
          pool: targetPool,
          storageKabadiwala: assignedHost,
        );
      }

      return RoutingResult(
        outcome: targetPool.isThresholdMet
            ? RoutingOutcome.poolReadyForPickup
            : RoutingOutcome.pooling,
        recycler: bestRecycler,
        pool: targetPool,
      );
    } catch (e) {
      debugPrint('[ROUTING ERROR] $e');
      return const RoutingResult(outcome: RoutingOutcome.noRecyclerAvailable);
    }
  }
}
