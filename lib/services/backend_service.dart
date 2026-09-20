import 'package:dio/dio.dart';
import '../models/lot.dart';
import '../models/pool.dart';
import '../models/recycler.dart';
import '../models/collector_store.dart'; // Imported for collector_id
import 'api_client.dart';

/// Concrete client-side backend service communicating with the central
/// FastAPI + MySQL platform.
class BackendService {
  final Dio _dio = ApiClient().dio;

  /// Fetches verified, authorized recyclers from the database.
  Future<List<Recycler>> getRecyclers({String? category}) async {
    try {
      final response = await _dio.get(
        '/recyclers',
        queryParameters: category != null ? {'category': category} : null,
      );
      final list = (response.data as List<dynamic>)
          .map((item) => Recycler.fromJson(item as Map<String, dynamic>))
          .toList();
      return list;
    } on DioException {
      // Graceful fallback for offline development
      return [];
    }
  }

  /// Fetches active collecting pools.
  Future<List<Pool>> getPools({String? category, String? recyclerId}) async {
    try {
      final response = await _dio.get(
        '/pools',
        queryParameters: {
          if (category != null) 'category': category,
          if (recyclerId != null) 'recycler_id': recyclerId,
        },
      );
      final list = (response.data as List<dynamic>)
          .map((item) => Pool.fromJson(item as Map<String, dynamic>))
          .toList();
      return list;
    } on DioException {
      return [];
    }
  }

  /// Contributes a lot to an active pool on the server.
  Future<bool> contributeToPool({
    required String poolId,
    required String lotId,
    required double weightKg,
    required String collectorLabel,
  }) async {
    try {
      final response = await _dio.post(
        '/pools/$poolId/contribute',
        data: {
          'lot_id': lotId,
          'weight_kg': weightKg,
          'collector_label': collectorLabel,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Sends a single lot payload to the backend.
  Future<bool> postLot(Lot lot) async {
    try {
      final payload = {
        'lot_id': lot.id,
        'collector_id': CollectorStore.getOrCreate().collectorId,
        'pipeline_route':
            lot.category == 'MixedPlastics' ? 'MIXED_PLASTICS' : 'E_WASTE',
        'category': lot.category,
        'sub_category': lot.subCategory,
        'approx_weight_kg': lot.approxWeightKg,
        'weight_source': 'user_input',
        'photo_urls': lot.photoPaths,
        'estimated_value': lot.estimatedValue,
        'quoted_price': lot.quotedPrice,
        'final_sale_value': lot.finalSaleValue,
        'created_at': lot.createdAt.toIso8601String(),
        'collection_latitude': lot.latitude,
        'collection_longitude': lot.longitude,
        'recycler_id': lot.recyclerId,
      };

      final response = await _dio.post(
        '/lots',
        data: payload,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Submits completed Form-6 checkpoints to the compliance ledger.
  Future<bool> submitManifestCheckpoint({
    required String manifestId,
    required String stage,
    required String signatureHash,
    required String cumulativeHash,
    required DateTime timestamp,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _dio.post(
        '/manifests/checkpoint',
        data: {
          'manifest_id': manifestId,
          'stage': stage,
          'signature_hash': signatureHash,
          'cumulative_hash': cumulativeHash,
          'timestamp': timestamp.toIso8601String(),
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
