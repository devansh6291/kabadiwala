import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Centralized Dio client managing interceptors, authentication headers,
/// timeouts, and host routing.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  /// Default API base URL:
  /// - Android Emulator maps to 10.0.2.2:8000
  /// - iOS Simulator / Web / Desktop maps to 127.0.0.1:8000
  /// Default API base URL:
  /// - Physical phone on Wi-Fi connects to host PC IP
  /// - USB reverse maps to 127.0.0.1:8000
  /// - Emulator maps to 10.0.2.2:8000
  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (Platform.isAndroid) return 'http://10.77.222.41:8000';
    return 'http://127.0.0.1:8000';
  }

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: defaultBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Inject Firebase Auth JWT token if available
          try {
            final token = await FirebaseService().getIdToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            debugPrint('[ApiClient] Token retrieval notice: $e');
          }

          debugPrint('--> [DIO] ${options.method} ${options.uri}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
              '<-- [DIO] ${response.statusCode} ${response.requestOptions.uri}');
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          // Auto-fallback: If LAN IP or localhost fails due to connection error or timeout,
          // try alternative candidate host on Android (e.g. Wi-Fi vs USB adb reverse)
          if (!kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android &&
              (error.type == DioExceptionType.connectionError ||
                  error.type == DioExceptionType.connectionTimeout)) {
            final currentUrl = error.requestOptions.baseUrl;
            String? candidate;
            if (currentUrl.contains('10.77.222.41')) {
              candidate = 'http://127.0.0.1:8000';
            } else if (currentUrl.contains('127.0.0.1')) {
              candidate = 'http://10.77.222.41:8000';
            }

            if (candidate != null && !error.requestOptions.extra.containsKey('retried')) {
              debugPrint('[DIO] Retrying request on alternative host: $candidate');
              final options = error.requestOptions;
              options.baseUrl = candidate;
              options.extra['retried'] = true;
              dio.options.baseUrl = candidate;
              try {
                final response = await dio.fetch(options);
                return handler.resolve(response);
              } catch (_) {
                // If candidate also fails, proceed with original error
              }
            }
          }

          debugPrint(
              '[DIO ERROR] ${error.type} (${error.response?.statusCode}) => ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  void updateBaseUrl(String newUrl) {
    dio.options.baseUrl = newUrl;
  }
}
