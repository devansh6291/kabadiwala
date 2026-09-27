import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/lot.dart';
import '../models/lot_store.dart';
import '../models/collector_store.dart';
import 'api_client.dart';
import 'firebase_service.dart';
import 'backend_service.dart';

/// Background synchronization manager:
/// Scans local Hive storage for pending lots, uploads photos to Firebase Storage,
/// and posts records to the central MySQL database via Dio.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  final Dio _dio = ApiClient().dio;
  final FirebaseService _firebaseService = FirebaseService();
  bool _isSyncing = false;

  SyncService._internal();

  /// Scans Hive and drains the pending sync queue.
  Future<int> syncPendingLots() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    int syncedCount = 0;
    try {
      final allLots = LotStore.getAllLots();
      final pendingLots = allLots.where((l) =>
          l.syncStatus == 'pending' ||
          l.syncStatus == 'failed' ||
          (l.paymentStatus == 'paid' && !l.paymentSynced)).toList();

      debugPrint('[SYNC] Processing ${pendingLots.length} pending lot(s)...');

      for (final lot in pendingLots) {
        var updated = lot;
        if (lot.syncStatus == 'pending' || lot.syncStatus == 'failed') {
          final success = await _uploadSingleLot(lot);
          updated = updated.copyWith(syncStatus: success ? 'synced' : 'failed');
          if (success) {
            syncedCount++;
            debugPrint('[SYNC] Lot ${lot.id} successfully synced.');
          } else {
            debugPrint('[SYNC] Failed to sync Lot ${lot.id}.');
          }
        }
        if (lot.paymentStatus == 'paid' && !lot.paymentSynced) {
          final paymentSynced = await BackendService().recordPayment(
            lotId: lot.id,
            method: lot.paymentMethod ?? 'cash',
            amount: lot.finalSaleValue ?? 0,
            recyclerId: lot.recyclerId,
          );
          updated = updated.copyWith(paymentSynced: paymentSynced);
          if (paymentSynced) syncedCount++;
        }
        await LotStore.updateLot(updated);
      }
    } catch (e) {
      debugPrint('[SYNC ERROR] Sync pass failed: $e');
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }

  Future<bool> _uploadSingleLot(Lot lot) async {
    try {
      final List<String> remotePhotoUrls = [];

      // Step 1: Upload local photos directly to Firebase Cloud Storage
      for (final localPath in lot.photoPaths) {
        if (!localPath.startsWith('http')) {
          try {
            final cloudUrl = await _firebaseService.uploadLotPhoto(
              lotId: lot.id,
              localPath: localPath,
            );
            remotePhotoUrls.add(cloudUrl);
          } catch (e) {
            debugPrint('[STORAGE ERROR] Failed photo upload: $e');
            remotePhotoUrls.add(localPath);
          }
        } else {
          remotePhotoUrls.add(localPath);
        }
      }

      // Step 2: Post the structured Lot record to MySQL via Dio
      final payload = {
        'lot_id': lot.id,
        'collector_id': CollectorStore.getOrCreate().collectorId,
        'pipeline_route':
            lot.category == 'MixedPlastics' ? 'MIXED_PLASTICS' : 'E_WASTE',
        'category': lot.category,
        'sub_category': lot.subCategory,
        'approx_weight_kg': lot.approxWeightKg,
        'weight_source': 'user_input',
        'photo_urls': remotePhotoUrls,
        'estimated_value': lot.estimatedValue,
        'quoted_price': lot.quotedPrice,
        'final_sale_value': lot.finalSaleValue,
        'created_at': lot.createdAt.toIso8601String(),
        'collection_latitude': lot.latitude,
        'collection_longitude': lot.longitude,
        'recycler_id': lot.recyclerId,
      };

      final response = await _dio.post('/lots', data: payload);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[SYNC FAIL] Error posting lot ${lot.id}: $e');
      return false;
    }
  }
}
