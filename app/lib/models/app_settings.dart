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
    this.model = 'qwen2.5-coder:3b',
    this.useLocalAi = false,
    this.projectContext = 'default-flutter-app',
    this.runtimeContext = 'Flutter 3.x / Dart 3.x (Windows)',
  });

  AppSettings copyWith({
    String? serviceUrl,
    String? model,
    bool? useLocalAi,
    String? projectContext,
    String? runtimeContext,
  }) {
    return AppSettings(
      serviceUrl: serviceUrl ?? this.serviceUrl,
      model: model ?? this.model,
      useLocalAi: useLocalAi ?? this.useLocalAi,
      projectContext: projectContext ?? this.projectContext,
      runtimeContext: runtimeContext ?? this.runtimeContext,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'service_url': serviceUrl.trim(),
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

    return AppSettings(
      serviceUrl: nonEmptyOr(json['service_url'], 'http://127.0.0.1:11435'),
      model: nonEmptyOr(json['model'], 'qwen2.5-coder:3b'),
      useLocalAi: json['use_local_ai'] == true,
      projectContext:
          nonEmptyOr(json['project_context'], 'default-flutter-app'),
      runtimeContext: nonEmptyOr(
        json['runtime_context'],
        'Flutter 3.x / Dart 3.x (Windows)',
      ),
    );
  }
}
