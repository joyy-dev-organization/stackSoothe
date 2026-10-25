import 'dart:convert';
import 'dart:io';

import '../models/diagnosis_result.dart';
import '../models/notebook_entry.dart';
import '../utils/error_fingerprint.dart';

/// Local atomic Fix Notebook store for StackSoothe.
///
/// Key guarantees (W3 M2):
/// - Saved diagnoses always start [VerificationStatus.unverified].
/// - Exact-match lookup uses composite key (`errorSignatureHash` + `sourceContextHash`
///   + `runtimeContextHash`).
/// - Changed source, runtime, or project context never returns an exact match;
///   it returns [NotebookMatchKind.similarContextChanged] requiring user review.
/// - Atomic write-temp-then-rename (`notebook.json.tmp.<ts>` -> `notebook.json`).
/// - Corrupt/truncated store on load is backed up to `notebook.json.corrupt.<ts>.bak`
///   and surfaces [lastCorruptionWarning] rather than failing silently.
/// - Runtime bearer tokens are never accepted or persisted.
class NotebookStore {
  static const int currentSchemaVersion = 1;
  static const int maxEntries = 100;
  static const int maxFileBytes = 2 * 1024 * 1024; // 2 MB cap
  static const String fileName = 'notebook.json';

  final Directory storageDirectory;
  final List<NotebookEntry> _entries = <NotebookEntry>[];
  final Map<String, NotebookEntry> _exactIndex = <String, NotebookEntry>{};
  final Map<String, List<NotebookEntry>> _signatureIndex =
      <String, List<NotebookEntry>>{};

  String? _lastCorruptionWarning;
  int _idCounter = 0;

  NotebookStore({Directory? storageDirectory})
    : storageDirectory = storageDirectory ?? resolveDefaultStorageDirectory();

  /// Resolves a local app data directory outside the git repo and outside
  /// OneDrive/Documents cloud-synced folders on Windows (`%LOCALAPPDATA%\StackSoothe`).
  static Directory resolveDefaultStorageDirectory() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.trim().isNotEmpty) {
      return Directory('$localAppData${Platform.pathSeparator}StackSoothe');
    }
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return Directory('$home${Platform.pathSeparator}.stacksoothe_local');
    }
    return Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}StackSoothe',
    );
  }

  File get notebookFile =>
      File('${storageDirectory.path}${Platform.pathSeparator}$fileName');

  List<NotebookEntry> get entries => List<NotebookEntry>.unmodifiable(_entries);

  String? get lastCorruptionWarning => _lastCorruptionWarning;

  void dismissCorruptionWarning() {
    _lastCorruptionWarning = null;
  }

  /// Loads entries from disk, rebuilding exact and similar lookup indices.
  /// If `notebook.json` is corrupt or truncated, preserves a `.bak` copy and
  /// sets [lastCorruptionWarning].
  void load() {
    _entries.clear();
    _exactIndex.clear();
    _signatureIndex.clear();

    final file = notebookFile;
    if (!file.existsSync()) {
      return;
    }

    try {
      final stat = file.statSync();
      if (stat.size > maxFileBytes) {
        throw const FormatException(
          'Notebook store exceeded 2 MB safety limit',
        );
      }
      final rawBytes = file.readAsBytesSync();
      final rawText = utf8.decode(rawBytes);
      final decoded = jsonDecode(rawText);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Notebook root must be a JSON object');
      }
      if (decoded['schema_version'] != currentSchemaVersion) {
        throw FormatException(
          'Unsupported notebook schema_version: ${decoded['schema_version']}',
        );
      }

      final rawList = decoded['entries'];
      if (rawList is! List) {
        throw const FormatException(
          'Notebook entries field must be a JSON list',
        );
      }

      final parsedEntries = <NotebookEntry>[];
      for (final item in rawList) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException(
            'Notebook entry item must be a JSON object',
          );
        }
        // Fail-closed / strip any accidental token fields
        if (item.containsKey('serviceToken') ||
            item.containsKey('service_token') ||
            item.containsKey('token')) {
          item.remove('serviceToken');
          item.remove('service_token');
          item.remove('token');
        }
        parsedEntries.add(NotebookEntry.fromJson(item));
      }

      _entries.addAll(parsedEntries.take(maxEntries));
      _rebuildIndices();
    } catch (e) {
      final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
      final backupPath = '${file.path}.corrupt.$ts.bak';
      try {
        file.copySync(backupPath);
        file.deleteSync();
      } catch (_) {
        // If copy+delete fails, attempt direct rename
        try {
          file.renameSync(backupPath);
        } catch (_) {}
      }
      _entries.clear();
      _exactIndex.clear();
      _signatureIndex.clear();
      _lastCorruptionWarning =
          'Corrupt or truncated Fix Notebook detected on startup. '
          'Backed up broken store to $backupPath and initialized a clean notebook.';
    }
  }

  /// Looks up whether the given error + source + project/runtime context has an
  /// exact match or a context-changed similar match.
  NotebookLookupResult lookup({
    required String errorLog,
    required String codeContext,
    required String projectContext,
    required String runtimeContext,
  }) {
    if (errorLog.trim().isEmpty) {
      return const NotebookLookupResult.none();
    }

    final fp = ErrorFingerprint.compute(
      errorLog: errorLog,
      codeContext: codeContext,
      projectContext: projectContext,
      runtimeContext: runtimeContext,
    );

    final exact = _exactIndex[fp.compositeExactKey];
    if (exact != null) {
      return NotebookLookupResult.exact(exact);
    }

    final sameSignature = _signatureIndex[fp.errorSignatureHash];
    if (sameSignature != null && sameSignature.isNotEmpty) {
      var sourceDiff = false;
      var runtimeDiff = false;
      for (final candidate in sameSignature) {
        if (candidate.sourceContextHash != fp.sourceContextHash) {
          sourceDiff = true;
        }
        if (candidate.runtimeContextHash != fp.runtimeContextHash) {
          runtimeDiff = true;
        }
      }
      return NotebookLookupResult.similar(
        entries: List<NotebookEntry>.unmodifiable(sameSignature),
        sourceChanged: sourceDiff,
        runtimeChanged: runtimeDiff,
      );
    }

    return const NotebookLookupResult.none();
  }

  /// Saves a diagnosis to the notebook. Always starts as [VerificationStatus.unverified].
  /// The AI never self-certifies.
  NotebookEntry saveNewDiagnosis({
    required String errorLog,
    required String codeContext,
    required String projectContext,
    required String runtimeContext,
    required DiagnosisResult diagnosis,
  }) {
    final fp = ErrorFingerprint.compute(
      errorLog: errorLog,
      codeContext: codeContext,
      projectContext: projectContext,
      runtimeContext: runtimeContext,
    );

    final nowIso = DateTime.now().toUtc().toIso8601String();
    _idCounter++;
    final entryId =
        'nb_${DateTime.now().toUtc().microsecondsSinceEpoch}_$_idCounter';

    final recalledDiagnosis = diagnosis.copyWith(
      isRecalled: true,
      recalledEntryId: entryId,
    );

    final newEntry = NotebookEntry(
      id: entryId,
      createdAtIso: nowIso,
      updatedAtIso: nowIso,
      compositeExactKey: fp.compositeExactKey,
      errorSignatureHash: fp.errorSignatureHash,
      sourceContextHash: fp.sourceContextHash,
      runtimeContextHash: fp.runtimeContextHash,
      errorLog: errorLog,
      codeContext: codeContext,
      projectContext: projectContext.trim().isEmpty
          ? 'default-flutter-app'
          : projectContext.trim(),
      runtimeContext: runtimeContext.trim().isEmpty
          ? 'Flutter 3.x / Dart 3.x (Windows)'
          : runtimeContext.trim(),
      modelName: diagnosis.modelName,
      promptVersion: diagnosis.promptVersion,
      verificationStatus: VerificationStatus.unverified,
      verifiedAtIso: null,
      verificationNote: null,
      diagnosis: recalledDiagnosis,
    );

    // Replace existing entry if identical compositeExactKey already exists
    _entries.removeWhere((e) => e.compositeExactKey == fp.compositeExactKey);

    // Insert newest first
    _entries.insert(0, newEntry);

    // Bound entry count
    while (_entries.length > maxEntries) {
      _entries.removeLast();
    }

    _rebuildIndices();
    _persistAtomically();
    return newEntry;
  }

  /// Explicit user action to mark an entry verified or unverified.
  NotebookEntry updateVerification({
    required String entryId,
    required VerificationStatus status,
    String? verificationNote,
  }) {
    final idx = _entries.indexWhere((e) => e.id == entryId);
    if (idx < 0) {
      throw StateError('NotebookEntry not found: $entryId');
    }

    final updated = _entries[idx].copyWithVerification(
      status: status,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
      verificationNote: verificationNote,
    );
    _entries[idx] = updated;
    _rebuildIndices();
    _persistAtomically();
    return updated;
  }

  /// Deletes a single entry by ID and removes it from all lookup indices.
  bool deleteEntry(String entryId) {
    final before = _entries.length;
    _entries.removeWhere((e) => e.id == entryId);
    if (_entries.length == before) {
      return false;
    }
    _rebuildIndices();
    _persistAtomically();
    return true;
  }

  /// Clears all saved entries and lookup indices.
  void clearAll() {
    _entries.clear();
    _exactIndex.clear();
    _signatureIndex.clear();
    _persistAtomically();
  }

  void _rebuildIndices() {
    _exactIndex.clear();
    _signatureIndex.clear();
    for (final entry in _entries) {
      _exactIndex.putIfAbsent(entry.compositeExactKey, () => entry);
      _signatureIndex
          .putIfAbsent(entry.errorSignatureHash, () => <NotebookEntry>[])
          .add(entry);
    }
  }

  void _persistAtomically() {
    if (!storageDirectory.existsSync()) {
      storageDirectory.createSync(recursive: true);
    }

    final payload = <String, dynamic>{
      'schema_version': currentSchemaVersion,
      'updated_at_iso': DateTime.now().toUtc().toIso8601String(),
      'entries': _entries.map((e) => e.toJson()).toList(),
    };

    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    final bytes = utf8.encode(encoded);
    if (bytes.length > maxFileBytes) {
      throw StateError('Serialized Fix Notebook exceeds 2 MB limit');
    }

    final target = notebookFile;
    final tmpFile = File(
      '${target.path}.tmp.${DateTime.now().toUtc().microsecondsSinceEpoch}',
    );

    tmpFile.writeAsBytesSync(bytes, flush: true);
    try {
      tmpFile.renameSync(target.path);
    } catch (_) {
      if (target.existsSync()) {
        target.deleteSync();
      }
      tmpFile.renameSync(target.path);
    }
  }
}
