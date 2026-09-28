import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/lot.dart';
import '../models/lot_store.dart';
import '../models/pool.dart';
import '../models/recycler.dart';
import '../models/storage_host.dart';
import '../data/demo_recycler_directory.dart';
import '../models/collector_store.dart';
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
  final bool isSampleData;

  const RoutingResult({
    required this.outcome,
    this.recycler,
    this.pool,
    this.storageKabadiwala,
    this.isSampleData = false,
  });
}

/// Cloud-connected matching engine hitting the FastAPI + MySQL endpoints.
class RecyclerMatchingService {
  static Future<RoutingResult> route(Lot lot,
      {required bool hasStorage}) async {
    final dio = ApiClient().dio;

    try {
      // Use the location captured for this lot. Never substitute a made-up
      // city coordinate when location access is unavailable.
      final profile = CollectorStore.getOrCreate();
      final pos = lot.latitude == null || lot.longitude == null
          ? await LocationService.getCurrentPosition()
          : null;
      final lat = lot.latitude ?? pos?.latitude ?? profile.latitude;
      final lng = lot.longitude ?? pos?.longitude ?? profile.longitude;
      if (lat == null || lng == null) {
        debugPrint(
            '[ROUTING] Missing collection location: ${LocationService.lastError}');
        await LotStore.updateLot(lot.copyWith(routingStatus: 'failed'));
        return const RoutingResult(outcome: RoutingOutcome.noRecyclerAvailable);
      }
      if (lot.latitude == null || lot.longitude == null) {
        lot.latitude = lat;
        lot.longitude = lng;
        await LotStore.updateLot(lot);
      }

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
        return await _readySampleRoute(lot);
      }

      final candidates = recyclerData
          .map((j) => Recycler.fromJson(j))
          .where((recycler) => recycler.materialsAccepted.any((material) =>
              material.toLowerCase() == lot.category.toLowerCase()))
          .toList();
      if (candidates.isEmpty) return await _readySampleRoute(lot);

      // Sort by best offered rate for the material
      candidates.sort((a, b) {
        final rateA = a.offeredRates[lot.category] ?? 0;
        final rateB = b.offeredRates[lot.category] ?? 0;
        final relativeRateGap = (rateA - rateB).abs() /
            (rateA > rateB ? rateA : rateB).clamp(1, double.infinity);
        // Prefer a materially better offer; when rates are close, prefer
        // pickup availability and then the nearer authorized facility.
        if (relativeRateGap >= 0.10) return rateB.compareTo(rateA);
        int availability(String value) {
          final normalized = value.toLowerCase();
          if (normalized.contains('immediate') || normalized.contains('same'))
            return 0;
          if (normalized.contains('scheduled')) return 1;
          if (normalized.contains('none')) return 2;
          return 1;
        }

        final byAvailability = availability(a.pickupAvailability)
            .compareTo(availability(b.pickupAvailability));
        if (byAvailability != 0) return byAvailability;
        return (a.distanceKm ?? double.infinity)
            .compareTo(b.distanceKm ?? double.infinity);
      });
      final bestRecycler = candidates.first;
      await LotStore.updateLot(lot.copyWith(
        recyclerId: bestRecycler.recyclerId,
        recyclerSnapshot: bestRecycler.toJson(),
        routingStatus: 'routed',
      ));

      // Make a logistics request visible in the matched recycler's inbox.
      // This is best-effort and never blocks the collector's offline flow.
      try {
        final collector = CollectorStore.getOrCreate();
        await dio.post('/logistics-requests', data: {
          'recyclerId': bestRecycler.recyclerId,
          'collectorId': collector.collectorId,
          'collectorName':
              collector.name.isEmpty ? 'Collector' : collector.name,
          'collectorPhone': collector.phoneNumber,
          'collectorLocation': collector.operatingLocation,
          'lotId': lot.id,
          'category': lot.category,
          'subCategory': lot.subCategory,
          'approxWeightKg': lot.approxWeightKg,
          'estimatedValue': lot.estimatedValue,
          'quotedPrice': lot.quotedPrice,
          'lotLatitude': lot.latitude,
          'lotLongitude': lot.longitude,
          'photoRefs': lot.photoPaths,
          'status': 'requested',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('[LOGISTICS REQUEST NOTICE] $e');
      }

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
              p.status == PoolStatus.storageNeeded ||
              p.status == PoolStatus.readyForPickup)
          .toList();

      final existingWeight =
          activePools.isEmpty ? 0.0 : activePools.first.totalWeightKg;
      final requiredWeight = activePools.isEmpty
          ? bestRecycler.minVehicleCapacityKg
          : activePools.first.thresholdKg;
      if (existingWeight + lot.approxWeightKg < requiredWeight) {
        // Keep the real collecting pool untouched while still allowing a
        // complete, clearly identified walkthrough on an underfilled lot.
        return await _readySampleRoute(lot);
      }

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
      return await _readySampleRoute(lot);
    }
  }

  static Future<RoutingResult> _readySampleRoute(Lot lot) async {
    final matchingSamples = DemoRecyclerDirectory.forMaterial(lot.category);
    final recycler = matchingSamples.isNotEmpty
        ? matchingSamples.first
        : DemoRecyclerDirectory.recyclers.first;
    await LotStore.updateLot(lot.copyWith(
      recyclerId: recycler.recyclerId,
      recyclerSnapshot: recycler.toJson(),
      routingStatus: 'routed',
    ));
    final weight = lot.approxWeightKg > 0 ? lot.approxWeightKg : 0.1;
    final pool = Pool(
      id: 'sample-pool-${lot.id}',
      category: lot.category,
      recyclerId: recycler.recyclerId,
      thresholdKg: weight,
      entries: [
        LotPoolEntry(
          lotId: lot.id,
          collectorLabel: 'You',
          weightKg: weight,
        ),
      ],
      status: PoolStatus.readyForPickup,
      createdAt: DateTime.now(),
    );
    return RoutingResult(
      outcome: RoutingOutcome.poolReadyForPickup,
      recycler: recycler,
      pool: pool,
      isSampleData: true,
    );
  }
}
