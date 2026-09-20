import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'classifier_service.dart';

/// Calls the real ML model over HTTP (see ai_model/server.py, which
/// wraps KabadiwalaAIInferenceEngine.predict()). Swap this in for
/// ManualClassifierService once server.py is confirmed working — no
/// other app code changes, since both implement ClassifierService.
class ApiClassifierService implements ClassifierService {
  final String baseUrl;

  ApiClassifierService({required this.baseUrl});

  @override
  Future<DetectedItem> classifyOne({
    required String photoPath,
    double? approxWeightKg,
  }) async {
    final uri = Uri.parse('$baseUrl/classify');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', photoPath));
    if (approxWeightKg != null) {
      request.fields['approx_weight_kg'] = approxWeightKg.toString();
    }

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
          'Classifier API returned ${response.statusCode}: ${response.body}');
    }

    debugPrint('RAW CLASSIFY RESPONSE: ${response.body}');

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;

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
}
