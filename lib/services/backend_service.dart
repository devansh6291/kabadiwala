import 'package:dio/dio.dart';
import '../models/lot.dart';
import '../models/pool.dart';
import '../models/recycler.dart';
import '../models/collector_store.dart'; // Imported for collector_id
import '../data/demo_recycler_directory.dart';
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
      if (list.isNotEmpty) return list;
      return _sampleRecyclers(category);
    } catch (_) {
      return _sampleRecyclers(category);
    }
  }

  List<Recycler> _sampleRecyclers(String? category) {
    final samples = DemoRecyclerDirectory.recyclers;
    if (category == null) return samples;
    return samples
        .where((recycler) => recycler.materialsAccepted.contains(category))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getCollectorTransactions() async {
    try {
      final collectorId = CollectorStore.getOrCreate().collectorId;
      final response = await _dio.get('/transactions',
          queryParameters: {'collector_id': collectorId});
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> getCollectorPayments() async {
    try {
      final collectorId = CollectorStore.getOrCreate().collectorId;
      final response = await _dio.get('/payments',
          queryParameters: {'collector_id': collectorId});
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) {
      return const [];
    }
  }

  Future<bool> recordPayment({
    required String lotId,
    required String transactionId,
    required String method,
    required double amount,
    required DateTime recordedAt,
    String? recyclerId,
  }) async {
    try {
      final response = await _dio.post('/payments', data: {
        'id': transactionId,
        'lot_id': lotId,
        'collector_id': CollectorStore.getOrCreate().collectorId,
        'recycler_id': recyclerId,
        'amount': amount,
        'method': method,
        'status': 'paid',
        'recorded_at': recordedAt.toUtc().toIso8601String(),
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
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
