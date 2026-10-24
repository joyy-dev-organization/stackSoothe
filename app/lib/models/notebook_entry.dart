import 'diagnosis_result.dart';

/// User-controlled verification state for a saved diagnosis.
///
/// Per W3 M2 rules: a saved diagnosis MUST start [unverified]. Only an explicit
/// user action transitions it to [verified]. The AI never self-certifies.
enum VerificationStatus {
  unverified,
  verified;

  String toJsonValue() => name.toUpperCase();

  static VerificationStatus fromJsonValue(Object? raw) {
    if (raw is String && raw.toUpperCase() == 'VERIFIED') {
      return VerificationStatus.verified;
    }
    if (raw is String && raw.toUpperCase() == 'UNVERIFIED') {
      return VerificationStatus.unverified;
    }
    throw FormatException('Invalid verification_status: $raw');
  }
}

class NotebookEntry {
  final String id;
  final String createdAtIso;
  final String updatedAtIso;
  final String compositeExactKey;
  final String errorSignatureHash;
  final String sourceContextHash;
  final String runtimeContextHash;
  final String errorLog;
  final String codeContext;
  final String projectContext;
  final String runtimeContext;
  final String modelName;
  final String promptVersion;
  final VerificationStatus verificationStatus;
  final String? verifiedAtIso;
  final String? verificationNote;
  final DiagnosisResult diagnosis;

  const NotebookEntry({
    required this.id,
    required this.createdAtIso,
    required this.updatedAtIso,
    required this.compositeExactKey,
    required this.errorSignatureHash,
    required this.sourceContextHash,
    required this.runtimeContextHash,
    required this.errorLog,
    required this.codeContext,
    required this.projectContext,
    required this.runtimeContext,
    required this.modelName,
    required this.promptVersion,
    this.verificationStatus = VerificationStatus.unverified,
    this.verifiedAtIso,
    this.verificationNote,
    required this.diagnosis,
  });

  bool get isVerified => verificationStatus == VerificationStatus.verified;

  NotebookEntry copyWithVerification({
    required VerificationStatus status,
    required String updatedAtIso,
    String? verificationNote,
  }) {
    final cleanNote = verificationNote?.trim();
    return NotebookEntry(
      id: id,
      createdAtIso: createdAtIso,
      updatedAtIso: updatedAtIso,
      compositeExactKey: compositeExactKey,
      errorSignatureHash: errorSignatureHash,
      sourceContextHash: sourceContextHash,
      runtimeContextHash: runtimeContextHash,
      errorLog: errorLog,
      codeContext: codeContext,
      projectContext: projectContext,
      runtimeContext: runtimeContext,
      modelName: modelName,
      promptVersion: promptVersion,
      verificationStatus: status,
      verifiedAtIso:
          status == VerificationStatus.verified ? updatedAtIso : null,
      verificationNote:
          (cleanNote != null && cleanNote.isNotEmpty) ? cleanNote : null,
      diagnosis: diagnosis,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'created_at_iso': createdAtIso,
      'updated_at_iso': updatedAtIso,
      'composite_exact_key': compositeExactKey,
      'error_signature_hash': errorSignatureHash,
      'source_context_hash': sourceContextHash,
      'runtime_context_hash': runtimeContextHash,
      'error_log': errorLog,
      'code_context': codeContext,
      'project_context': projectContext,
      'runtime_context': runtimeContext,
      'model_name': modelName,
      'prompt_version': promptVersion,
      'verification_status': verificationStatus.toJsonValue(),
      'verified_at_iso': verifiedAtIso,
      'verification_note': verificationNote,
      'diagnosis': diagnosis.toJson(),
    };
  }

  factory NotebookEntry.fromJson(Map<String, dynamic> json) {
    String requireStr(String key, {bool allowEmpty = false}) {
      final v = json[key];
      if (v is! String || (!allowEmpty && v.trim().isEmpty)) {
        throw FormatException('Missing or invalid NotebookEntry field: $key');
      }
      return v;
    }

    final id = requireStr('id');
    final diagMap = json['diagnosis'];
    if (diagMap is! Map<String, dynamic>) {
      throw const FormatException('Missing or invalid NotebookEntry diagnosis object');
    }

    final diagnosis = DiagnosisResult.fromNotebookJson(
      diagMap,
      isRecalled: true,
      recalledEntryId: id,
    );

    return NotebookEntry(
      id: id,
      createdAtIso: requireStr('created_at_iso'),
      updatedAtIso: requireStr('updated_at_iso'),
      compositeExactKey: requireStr('composite_exact_key'),
      errorSignatureHash: requireStr('error_signature_hash'),
      sourceContextHash: requireStr('source_context_hash'),
      runtimeContextHash: requireStr('runtime_context_hash'),
      errorLog: requireStr('error_log'),
      codeContext: requireStr('code_context', allowEmpty: true),
      projectContext: requireStr('project_context'),
      runtimeContext: requireStr('runtime_context'),
      modelName: requireStr('model_name'),
      promptVersion: requireStr('prompt_version'),
      verificationStatus:
          VerificationStatus.fromJsonValue(json['verification_status']),
      verifiedAtIso: json['verified_at_iso'] as String?,
      verificationNote: json['verification_note'] as String?,
      diagnosis: diagnosis,
    );
  }
}

enum NotebookMatchKind {
  none,
  exact,
  similarContextChanged,
}

class NotebookLookupResult {
  final NotebookMatchKind kind;
  final NotebookEntry? exactEntry;
  final List<NotebookEntry> similarEntries;
  final bool sourceChanged;
  final bool runtimeChanged;

  const NotebookLookupResult._({
    required this.kind,
    this.exactEntry,
    this.similarEntries = const [],
    this.sourceChanged = false,
    this.runtimeChanged = false,
  });

  const NotebookLookupResult.none()
      : this._(kind: NotebookMatchKind.none);

  const NotebookLookupResult.exact(NotebookEntry entry)
      : this._(
          kind: NotebookMatchKind.exact,
          exactEntry: entry,
        );

  const NotebookLookupResult.similar({
    required List<NotebookEntry> entries,
    required bool sourceChanged,
    required bool runtimeChanged,
  }) : this._(
          kind: NotebookMatchKind.similarContextChanged,
          similarEntries: entries,
          sourceChanged: sourceChanged,
          runtimeChanged: runtimeChanged,
        );
}
