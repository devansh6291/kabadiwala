import 'dart:convert';

import 'package:http/http.dart' as http;

import 'classifier_service.dart';

/// Calls the real ML model over HTTP (see ai-service/server.py, which
/// wraps KabadiwalaAIInferenceEngine.predict()). Swap this in for
/// ManualClassifierService once server.py is confirmed working — no
/// other app code changes, since both implement ClassifierService.
///
/// [baseUrl] example: 'http://192.168.1.42:8000' — your ML teammate's
/// laptop IP on the same WiFi network as the test phone. localhost will
/// NOT work here since the phone is a separate device from the server.
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

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;

    return DetectedItem(
      photoPath: photoPath,
      category: json['category'] as String,
      subCategory: json['subCategory'] as String?,
      estimatedWeightKg: (json['approxWeightKg'] as num).toDouble(),
      estimatedValue: (json['estimatedValue'] as num).toDouble(),
      condition: json['condition'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}
