class DiagnosisResult {
  const DiagnosisResult({
    required this.title,
    required this.severity,
    required this.summary,
    required this.likelyCause,
    required this.confidence,
    required this.steps,
    required this.verification,
    this.codeExample = '',
    this.modelName = 'Demo rules',
    this.promptVersion = 'demo-v1',
    this.isDemo = true,
    this.isRecalled = false,
    this.recalledEntryId,
  });

  final String title;
  final String severity;
  final String summary;
  final String likelyCause;
  final String confidence;
  final List<String> steps;
  final List<String> verification;
  final String codeExample;
  final String modelName;
  final String promptVersion;
  final bool isDemo;
  final bool isRecalled;
  final String? recalledEntryId;

  DiagnosisResult copyWith({
    String? title,
    String? severity,
    String? summary,
    String? likelyCause,
    String? confidence,
    List<String>? steps,
    List<String>? verification,
    String? codeExample,
    String? modelName,
    String? promptVersion,
    bool? isDemo,
    bool? isRecalled,
    String? recalledEntryId,
  }) {
    return DiagnosisResult(
      title: title ?? this.title,
      severity: severity ?? this.severity,
      summary: summary ?? this.summary,
      likelyCause: likelyCause ?? this.likelyCause,
      confidence: confidence ?? this.confidence,
      steps: steps ?? this.steps,
      verification: verification ?? this.verification,
      codeExample: codeExample ?? this.codeExample,
      modelName: modelName ?? this.modelName,
      promptVersion: promptVersion ?? this.promptVersion,
      isDemo: isDemo ?? this.isDemo,
      isRecalled: isRecalled ?? this.isRecalled,
      recalledEntryId: recalledEntryId ?? this.recalledEntryId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'severity': severity,
      'summary': summary,
      'likely_cause': likelyCause,
      'confidence': confidence,
      'steps': steps,
      'verification': verification,
      'code_example': codeExample,
      'model_name': modelName,
      'prompt_version': promptVersion,
      'is_demo': isDemo,
    };
  }

  /// Strict deserialization for saved Fix Notebook entries (throws FormatException
  /// if required fields are missing or invalid rather than substituting silent fallbacks).
  factory DiagnosisResult.fromNotebookJson(
    Map<String, dynamic> json, {
    bool isRecalled = true,
    String? recalledEntryId,
  }) {
    String requireString(String key) {
      final val = json[key];
      if (val is! String || val.trim().isEmpty) {
        throw FormatException(
          'Missing or invalid notebook diagnosis field: $key',
        );
      }
      return val;
    }

    List<String> requireStringList(String key) {
      final val = json[key];
      if (val is! List || val.isEmpty) {
        throw FormatException(
          'Missing or invalid notebook diagnosis list: $key',
        );
      }
      final list = val
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (list.isEmpty) {
        throw FormatException('Empty string list for notebook field: $key');
      }
      return list;
    }

    final severity = requireString('severity').toLowerCase();
    if (!const {'low', 'medium', 'high'}.contains(severity)) {
      throw FormatException('Invalid notebook diagnosis severity: $severity');
    }

    return DiagnosisResult(
      title: requireString('title'),
      severity: severity,
      summary: requireString('summary'),
      likelyCause: requireString('likely_cause'),
      confidence: requireString('confidence'),
      steps: requireStringList('steps'),
      verification: requireStringList('verification'),
      codeExample: (json['code_example'] as String?) ?? '',
      modelName: (json['model_name'] as String?) ?? 'unknown-model',
      promptVersion: (json['prompt_version'] as String?) ?? 'v1.0.0',
      isDemo: json['is_demo'] == true,
      isRecalled: isRecalled,
      recalledEntryId: recalledEntryId,
    );
  }

  factory DiagnosisResult.fromJson(
    Map<String, dynamic> json, {
    required String modelName,
  }) {
    String stringValue(String key, String fallback) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      return fallback;
    }

    List<String> listValue(String key, List<String> fallback) {
      final value = json[key];
      if (value is List) {
        final items = value
            .whereType<Object>()
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .take(5)
            .toList();
        if (items.isNotEmpty) return items;
      }
      return fallback;
    }

    final rawSeverity = stringValue('severity', 'medium').toLowerCase();
    final severity = const {'low', 'medium', 'high'}.contains(rawSeverity)
        ? rawSeverity
        : 'medium';

    return DiagnosisResult(
      title: stringValue('title', 'Potential issue identified'),
      severity: severity,
      summary: stringValue(
        'summary',
        'Review the likely cause and verify the suggested steps against your code.',
      ),
      likelyCause: stringValue(
        'likely_cause',
        'The supplied context is not sufficient to identify a single cause.',
      ),
      confidence: stringValue('confidence', 'Low'),
      steps: listValue('steps', const [
        'Read the first relevant error line and identify the file and line number.',
        'Reproduce the issue after making one change at a time.',
      ]),
      verification: listValue('verification', const [
        'Run the relevant test or reproduce the original action.',
      ]),
      codeExample: stringValue('code_example', ''),
      modelName: modelName,
      promptVersion: 'v1.0.0',
      isDemo: false,
    );
  }

  factory DiagnosisResult.fromEnvelope(Map<String, dynamic> envelope) {
    if (envelope['success'] != true) {
      final err = envelope['error'];
      final message = err is Map
          ? err['message'] ?? 'Diagnosis failed'
          : 'Diagnosis failed';
      throw Exception(message);
    }
    final data = envelope['data'] as Map<String, dynamic>? ?? {};
    final meta = envelope['meta'] as Map<String, dynamic>? ?? {};
    final model = meta['model'] as String? ?? 'qwen2.5-coder:3b';
    final promptVersion = meta['prompt_version'] as String? ?? 'v1.0.0';
    final repaired = meta['repaired'] == true;

    return DiagnosisResult(
      title: data['title'] as String? ?? 'Diagnosis',
      severity: data['severity'] as String? ?? 'medium',
      summary: data['summary'] as String? ?? '',
      likelyCause: data['likely_cause'] as String? ?? '',
      confidence: data['confidence'] as String? ?? 'Medium',
      steps:
          (data['steps'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      verification:
          (data['verification'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      codeExample: data['code_example'] as String? ?? '',
      modelName: repaired ? '$model (auto-repaired)' : model,
      promptVersion: promptVersion,
      isDemo: false,
    );
  }

  String toPlainText() {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln('Severity: ${severity.toUpperCase()}')
      ..writeln()
      ..writeln('Summary')
      ..writeln(summary)
      ..writeln()
      ..writeln('Likely cause')
      ..writeln(likelyCause)
      ..writeln()
      ..writeln('Suggested steps');

    for (var i = 0; i < steps.length; i++) {
      buffer.writeln('${i + 1}. ${steps[i]}');
    }

    buffer
      ..writeln()
      ..writeln('Verify the fix');
    for (final item in verification) {
      buffer.writeln('- $item');
    }

    if (codeExample.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Example')
        ..writeln(codeExample);
    }
    buffer
      ..writeln()
      ..writeln(
        'Generated by ${isDemo ? 'StackSoothe demo mode (RULE-BASED EXAMPLE — NOT AI INFERENCE)' : modelName} (prompt $promptVersion)${isRecalled ? ' — Recalled from Fix Notebook' : ''}.',
      );
    return buffer.toString();
  }
}
