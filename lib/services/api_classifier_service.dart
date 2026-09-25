import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'classifier_service.dart';

/// Calls the PyTorch inference engine running inside the FastAPI backend.
/// Automatically falls back to on-device/manual classification if the server
/// is unreachable, offline, or times out.
class ApiClassifierService implements ClassifierService {
  final Dio _dio;
  final ClassifierService _fallback = ManualClassifierService();

  ApiClassifierService({String? baseUrl}) : _dio = ApiClient().dio {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      _dio.options.baseUrl = baseUrl;
    }
  }

  @override
  Future<DetectedItem> classifyOne({
    required String photoPath,
    double? approxWeightKg,
  }) async {
    try {
      final fileName = photoPath.split(RegExp(r'[/\\]')).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          photoPath,
          filename: fileName.isNotEmpty ? fileName : 'photo.jpg',
        ),
        if (approxWeightKg != null) 'approx_weight_kg': approxWeightKg,
      });

      final response = await _dio.post(
        '/classify',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final Map<String, dynamic> json = response.data as Map<String, dynamic>;

        final Map<String, double>? confidenceScores =
            (json['confidence'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, ((v as num?) ?? 0).toDouble()));

        final Map<String, double>? materialComposition =
            (json['materialProbabilities'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, ((v as num?) ?? 0).toDouble()));

        return DetectedItem(
          photoPath: photoPath,
          category: (json['category'] as String?) ?? 'Unknown',
          subCategory: json['subCategory'] as String?,
          estimatedWeightKg:
              (json['approxWeightKg'] as num?)?.toDouble() ?? approxWeightKg ?? 0.5,
          estimatedValue: (json['estimatedValue'] as num?)?.toDouble() ?? 0.0,
          condition: json['physicalCondition'] as String?,
          confidence: confidenceScores?['category'],
          routeType: json['pipelineRoute'] as String?,
          materialComposition: materialComposition,
          detectedMaterials: (json['detectedMaterials'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
          confidenceScores: confidenceScores,
        );
      }
      throw Exception('Classifier API returned ${response.statusCode}: ${response.data}');
    } catch (e) {
      debugPrint('[ApiClassifierService] Online classification error ($e). Falling back to offline classification.');
      // Seamlessly fall back to rule-based offline classification so capturing images never fails
      return await _fallback.classifyOne(
        photoPath: photoPath,
        approxWeightKg: approxWeightKg,
      );
    }
  }
}
