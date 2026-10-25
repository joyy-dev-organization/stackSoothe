import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';
import '../models/diagnosis_result.dart';

class ServiceBusyException implements Exception {
  final String message;
  const ServiceBusyException([
    this.message =
        'Another diagnosis is currently in progress. StackSoothe operates single-concurrency without queuing.',
  ]);
  @override
  String toString() => message;
}

typedef DiagnosisHandler =
    Future<DiagnosisResult> Function({
      required String errorLog,
      required String sourceCode,
      required String model,
    });

class DiagnosisClient {
  DiagnosisClient({
    this.baseUrl = 'http://127.0.0.1:11435',
    this.token = '',
    this.model = 'qwen2.5-coder:3b',
    this.customHandler,
  });

  final String baseUrl;
  final String token;
  final String model;
  final DiagnosisHandler? customHandler;

  int _invocationCount = 0;
  HttpClient? _activeClient;

  /// Number of times [diagnose] was invoked on this client instance.
  int get invocationCount => _invocationCount;

  void resetInvocationCount() {
    _invocationCount = 0;
  }

  /// Cancels in-flight network requests immediately.
  void cancelPendingRequest() {
    _activeClient?.close(force: true);
    _activeClient = null;
  }

  String get _rootUrl => baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  Future<DiagnosisResult> diagnose({
    required String errorLog,
    required String sourceCode,
  }) async {
    _invocationCount++;

    if (customHandler != null) {
      return customHandler!(
        errorLog: errorLog,
        sourceCode: sourceCode,
        model: model,
      );
    }

    if (!AppSettings.isLoopbackUrl(_rootUrl)) {
      throw ArgumentError(
        'Private mode requires a loopback address (127.0.0.1 or localhost). Non-loopback URL "$_rootUrl" rejected.',
      );
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    _activeClient = client;

    try {
      final request = await client
          .postUrl(Uri.parse('$_rootUrl/api/diagnose'))
          .timeout(const Duration(seconds: 15));

      request.headers.contentType = ContentType.json;
      if (token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      request.add(
        utf8.encode(
          jsonEncode({
            'errorLog': errorLog,
            'sourceCode': sourceCode,
            'model': model,
          }),
        ),
      );

      final response = await request.close().timeout(
        const Duration(seconds: 135),
      );

      final responseText = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 135));

      if (response.statusCode == 429) {
        throw const ServiceBusyException();
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        try {
          final errJson = jsonDecode(responseText);
          if (errJson is Map) {
            if (errJson['error'] is Map &&
                errJson['error']['message'] != null) {
              throw Exception(errJson['error']['message'].toString());
            }
            if (errJson['message'] != null) {
              throw Exception(errJson['message'].toString());
            }
          }
        } on FormatException {
          // Response body was not JSON; fall through
        }
        throw Exception('Service returned HTTP ${response.statusCode}');
      }

      final envelope = jsonDecode(responseText) as Map<String, dynamic>;
      return DiagnosisResult.fromEnvelope(envelope);
    } on SocketException catch (err) {
      throw Exception(
        'Could not connect to StackSoothe service at $_rootUrl (${err.message}). Make sure the local service is running.',
      );
    } finally {
      if (_activeClient == client) {
        _activeClient = null;
      }
      client.close(force: true);
    }
  }

  Future<String> testConnection() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);

    try {
      final request = await client
          .getUrl(Uri.parse('$_rootUrl/health'))
          .timeout(const Duration(seconds: 5));

      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        return 'Connected to StackSoothe local service at $_rootUrl.';
      }
      return 'Service returned status ${response.statusCode}: $body';
    } on SocketException catch (err) {
      throw Exception(
        'Cannot reach local service at $_rootUrl (${err.message}). Start the service with "npm start".',
      );
    } finally {
      client.close(force: true);
    }
  }
}
