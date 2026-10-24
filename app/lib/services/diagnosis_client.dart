import 'dart:convert';
import 'dart:io';

import '../models/diagnosis_result.dart';

class DiagnosisClient {
  DiagnosisClient({
    this.baseUrl = 'http://127.0.0.1:11435',
    this.token = '',
    this.model = 'qwen2.5-coder:3b',
  });

  final String baseUrl;
  final String token;
  final String model;

  String get _rootUrl => baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  Future<DiagnosisResult> diagnose({
    required String errorLog,
    required String sourceCode,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);

    try {
      final request = await client
          .postUrl(Uri.parse('$_rootUrl/api/diagnose'))
          .timeout(const Duration(seconds: 15));

      request.headers.contentType = ContentType.json;
      if (token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      request.add(utf8.encode(jsonEncode({
        'errorLog': errorLog,
        'sourceCode': sourceCode,
        'model': model,
      })));

      final response = await request
          .close()
          .timeout(const Duration(seconds: 130));

      final responseText = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 130));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        try {
          final errJson = jsonDecode(responseText);
          if (errJson is Map && errJson['message'] != null) {
            throw Exception(errJson['message']);
          }
        } catch (_) {}
        throw Exception('Service returned HTTP ${response.statusCode}');
      }

      final envelope = jsonDecode(responseText) as Map<String, dynamic>;
      return DiagnosisResult.fromEnvelope(envelope);
    } on SocketException catch (err) {
      throw Exception(
        'Could not connect to StackSoothe service at $_rootUrl (${err.message}). Make sure the local service is running.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<String> testConnection() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);

    try {
      final request = await client
          .getUrl(Uri.parse('$_rootUrl/health'))
          .timeout(const Duration(seconds: 5));

      final response = await request.close().timeout(const Duration(seconds: 5));
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
