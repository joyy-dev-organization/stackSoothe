/// Persisted non-secret user configuration for StackSoothe.
///
/// Security invariant: Runtime bearer tokens (`serviceToken`) are NEVER stored
/// in [AppSettings] or written to disk.
class AppSettings {
  final String serviceUrl;
  final String model;
  final bool useLocalAi;
  final String projectContext;
  final String runtimeContext;

  const AppSettings({
    this.serviceUrl = 'http://127.0.0.1:11435',
    this.model = 'qwen3:1.7b',
    this.useLocalAi = false,
    this.projectContext = 'default-flutter-app',
    this.runtimeContext = 'Flutter 3.x / Dart 3.x (Windows)',
  });

  /// Validates that a URL points strictly to loopback (127.0.0.1, localhost, or ::1).
  static bool isLoopbackUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      if (uri.scheme != 'http' && uri.scheme != 'https') return false;
      final host = uri.host.toLowerCase().trim();
      return host == '127.0.0.1' || host == 'localhost' || host == '::1';
    } catch (_) {
      return false;
    }
  }

  AppSettings copyWith({
    String? serviceUrl,
    String? model,
    bool? useLocalAi,
    String? projectContext,
    String? runtimeContext,
  }) {
    final effectiveUrl = serviceUrl ?? this.serviceUrl;
    return AppSettings(
      serviceUrl: isLoopbackUrl(effectiveUrl) ? effectiveUrl : this.serviceUrl,
      model: model ?? this.model,
      useLocalAi: useLocalAi ?? this.useLocalAi,
      projectContext: projectContext ?? this.projectContext,
      runtimeContext: runtimeContext ?? this.runtimeContext,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'service_url': isLoopbackUrl(serviceUrl)
          ? serviceUrl.trim()
          : 'http://127.0.0.1:11435',
      'model': model.trim(),
      'use_local_ai': useLocalAi,
      'project_context': projectContext.trim(),
      'runtime_context': runtimeContext.trim(),
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    String nonEmptyOr(Object? val, String fallback) {
      if (val is String && val.trim().isNotEmpty) {
        return val.trim();
      }
      return fallback;
    }

    final rawUrl = nonEmptyOr(json['service_url'], 'http://127.0.0.1:11435');
    final safeUrl = isLoopbackUrl(rawUrl) ? rawUrl : 'http://127.0.0.1:11435';

    return AppSettings(
      serviceUrl: safeUrl,
      model: nonEmptyOr(json['model'], 'qwen2.5-coder:3b'),
      useLocalAi: json['use_local_ai'] == true,
      projectContext: nonEmptyOr(
        json['project_context'],
        'default-flutter-app',
      ),
      runtimeContext: nonEmptyOr(
        json['runtime_context'],
        'Flutter 3.x / Dart 3.x (Windows)',
      ),
    );
  }
}
