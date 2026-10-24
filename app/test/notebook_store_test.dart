import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stacksoothe/models/app_settings.dart';
import 'package:stacksoothe/models/diagnosis_result.dart';
import 'package:stacksoothe/models/notebook_entry.dart';
import 'package:stacksoothe/services/notebook_store.dart';
import 'package:stacksoothe/services/settings_store.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('stacksoothe_nb_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  DiagnosisResult sampleDiagnosis({
    String title = 'RenderFlex right overflow in Row',
    String modelName = 'qwen2.5-coder:3b',
    String promptVersion = 'v1.0.0',
  }) {
    return DiagnosisResult(
      title: title,
      severity: 'medium',
      summary: 'A Row child exceeded available horizontal constraints.',
      likelyCause: 'Unconstrained Text widget inside a Row.',
      confidence: 'High',
      steps: const [
        'Wrap the Text widget in Expanded or Flexible.',
        'Re-test on a narrow desktop viewport.',
      ],
      verification: const [
        'Run flutter test test/widget_test.dart',
      ],
      codeExample: 'Row(children: [Expanded(child: Text(label))])',
      modelName: modelName,
      promptVersion: promptVersion,
      isDemo: false,
    );
  }

  group('NotebookStore & SettingsStore (M2)', () {
    test(
        'S3: saved diagnosis starts UNVERIFIED; only explicit user updateVerification marks it VERIFIED with optional note',
        () {
      final store = NotebookStore(storageDirectory: tempDir)..load();

      final saved = store.saveNewDiagnosis(
        errorLog: 'RenderFlex overflowed by 28 pixels on the right.',
        codeContext: 'Row(children: [Text("long")])',
        projectContext: 'stacksoothe_app',
        runtimeContext: 'Flutter 3.24 / Windows',
        diagnosis: sampleDiagnosis(),
      );

      expect(saved.verificationStatus, equals(VerificationStatus.unverified));
      expect(saved.isVerified, isFalse);
      expect(saved.verifiedAtIso, isNull);
      expect(saved.verificationNote, isNull);

      final verified = store.updateVerification(
        entryId: saved.id,
        status: VerificationStatus.verified,
        verificationNote: 'flutter test passed (exit 0)',
      );

      expect(verified.verificationStatus, equals(VerificationStatus.verified));
      expect(verified.isVerified, isTrue);
      expect(verified.verifiedAtIso, isNotNull);
      expect(verified.verificationNote, equals('flutter test passed (exit 0)'));
    });

    test(
        'S1 & S2: exact context returns exact match; changed source, project, or runtime context returns similarContextChanged and never exact',
        () {
      final store = NotebookStore(storageDirectory: tempDir)..load();

      final saved = store.saveNewDiagnosis(
        errorLog:
            '2026-10-24T10:00:00Z RenderFlex overflowed by 28 pixels on the right.\n#0 RenderFlex.performLayout (package:flutter/rendering.dart:100:5)',
        codeContext: 'Row(children: [Text("long")])',
        projectContext: 'stacksoothe_app',
        runtimeContext: 'Flutter 3.24 / Windows',
        diagnosis: sampleDiagnosis(),
      );
      store.updateVerification(
        entryId: saved.id,
        status: VerificationStatus.verified,
        verificationNote: 'Verified on 3.24',
      );

      // Same error (even with different timestamp and line:col) + same source + same runtime -> EXACT
      final exactLookup = store.lookup(
        errorLog:
            '2026-10-24T19:55:00Z RenderFlex overflowed by 28 pixels on the right.\n#0 RenderFlex.performLayout (package:flutter/rendering.dart:145:9)',
        codeContext: 'Row(children: [Text("long")])',
        projectContext: 'stacksoothe_app',
        runtimeContext: 'Flutter 3.24 / Windows',
      );
      expect(exactLookup.kind, equals(NotebookMatchKind.exact));
      expect(exactLookup.exactEntry?.id, equals(saved.id));
      expect(exactLookup.exactEntry?.diagnosis.isRecalled, isTrue);
      expect(exactLookup.exactEntry?.promptVersion, equals('v1.0.0'));

      // Changed source code -> SIMILAR (never exact)
      final changedSourceLookup = store.lookup(
        errorLog:
            'RenderFlex overflowed by 28 pixels on the right.\n#0 RenderFlex.performLayout (package:flutter/rendering.dart:145:9)',
        codeContext: 'Row(children: [Icon(Icons.warning), Text("long")])',
        projectContext: 'stacksoothe_app',
        runtimeContext: 'Flutter 3.24 / Windows',
      );
      expect(
        changedSourceLookup.kind,
        equals(NotebookMatchKind.similarContextChanged),
      );
      expect(changedSourceLookup.exactEntry, isNull);
      expect(changedSourceLookup.sourceChanged, isTrue);
      expect(changedSourceLookup.runtimeChanged, isFalse);

      // Changed runtime/project context -> SIMILAR (never exact)
      final changedRuntimeLookup = store.lookup(
        errorLog:
            'RenderFlex overflowed by 28 pixels on the right.\n#0 RenderFlex.performLayout (package:flutter/rendering.dart:145:9)',
        codeContext: 'Row(children: [Text("long")])',
        projectContext: 'stacksoothe_app',
        runtimeContext: 'Flutter 3.27 / Windows',
      );
      expect(
        changedRuntimeLookup.kind,
        equals(NotebookMatchKind.similarContextChanged),
      );
      expect(changedRuntimeLookup.exactEntry, isNull);
      expect(changedRuntimeLookup.sourceChanged, isFalse);
      expect(changedRuntimeLookup.runtimeChanged, isTrue);
    });

    test(
        'save -> close -> relaunch reloads report, provenance, verification state, and settings without storing tokens',
        () {
      final store1 = NotebookStore(storageDirectory: tempDir)..load();
      final settings1 = SettingsStore(storageDirectory: tempDir)..load();

      final saved = store1.saveNewDiagnosis(
        errorLog: 'LateInitializationError: Field "client" has not been initialized.',
        codeContext: 'late final HttpClient client;',
        projectContext: 'payments_module',
        runtimeContext: 'Dart 3.5 / Windows',
        diagnosis: sampleDiagnosis(
          title: 'Uninitialized late field client',
          modelName: 'qwen2.5-coder:3b',
          promptVersion: 'v1.0.0',
        ),
      );
      store1.updateVerification(
        entryId: saved.id,
        status: VerificationStatus.verified,
        verificationNote: 'Initialized in initState()',
      );

      settings1.save(
        const AppSettings(
          serviceUrl: 'http://127.0.0.1:11435',
          model: 'qwen3:1.7b',
          useLocalAi: true,
          projectContext: 'payments_module',
          runtimeContext: 'Dart 3.5 / Windows',
        ),
      );

      // Simulate restart with fresh store instances pointing at same directory
      final store2 = NotebookStore(storageDirectory: tempDir)..load();
      final settings2 = SettingsStore(storageDirectory: tempDir)..load();

      expect(store2.entries.length, equals(1));
      final reloaded = store2.entries.first;
      expect(reloaded.id, equals(saved.id));
      expect(reloaded.verificationStatus, equals(VerificationStatus.verified));
      expect(reloaded.verificationNote, equals('Initialized in initState()'));
      expect(reloaded.modelName, equals('qwen2.5-coder:3b'));
      expect(reloaded.promptVersion, equals('v1.0.0'));
      expect(reloaded.diagnosis.title, equals('Uninitialized late field client'));

      expect(settings2.settings.model, equals('qwen3:1.7b'));
      expect(settings2.settings.useLocalAi, isTrue);
      expect(settings2.settings.projectContext, equals('payments_module'));

      // Verify no token fields exist on disk
      final notebookRaw = store2.notebookFile.readAsStringSync();
      final settingsRaw = settings2.settingsFile.readAsStringSync();
      expect(notebookRaw.contains('serviceToken'), isFalse);
      expect(settingsRaw.contains('serviceToken'), isFalse);
      expect(settingsRaw.contains('service_token'), isFalse);
    });

    test('deleting one entry or clearing all history removes saved content and index', () {
      final store = NotebookStore(storageDirectory: tempDir)..load();

      final entryA = store.saveNewDiagnosis(
        errorLog: 'Error A: Null check operator used on a null value',
        codeContext: 'final x = value!;',
        projectContext: 'app_a',
        runtimeContext: 'Flutter 3.24',
        diagnosis: sampleDiagnosis(title: 'Null check failure A'),
      );
      store.saveNewDiagnosis(
        errorLog: 'Error B: RangeError (index): Invalid value: Not in inclusive range',
        codeContext: 'final item = items[5];',
        projectContext: 'app_b',
        runtimeContext: 'Flutter 3.24',
        diagnosis: sampleDiagnosis(title: 'RangeError B'),
      );

      expect(store.entries.length, equals(2));

      // Delete entry A
      final removed = store.deleteEntry(entryA.id);
      expect(removed, isTrue);
      expect(store.entries.length, equals(1));

      final lookupA = store.lookup(
        errorLog: 'Error A: Null check operator used on a null value',
        codeContext: 'final x = value!;',
        projectContext: 'app_a',
        runtimeContext: 'Flutter 3.24',
      );
      expect(lookupA.kind, equals(NotebookMatchKind.none));

      // Clear all
      store.clearAll();
      expect(store.entries, isEmpty);
      final lookupB = store.lookup(
        errorLog: 'Error B: RangeError (index): Invalid value: Not in inclusive range',
        codeContext: 'final item = items[5];',
        projectContext: 'app_b',
        runtimeContext: 'Flutter 3.24',
      );
      expect(lookupB.kind, equals(NotebookMatchKind.none));

      // Reload from disk to confirm persistence of deletion
      final reloadedStore = NotebookStore(storageDirectory: tempDir)..load();
      expect(reloadedStore.entries, isEmpty);
    });

    test(
        'negative/fail-closed test: corrupt or truncated notebook.json creates .corrupt.<ts>.bak backup and warning without silent loss',
        () {
      final notebookFile =
          File('${tempDir.path}${Platform.pathSeparator}notebook.json');
      const corruptedContent = '{"schema_version": 1, "entries": [{"id": "nb_1", TRUNCATED';
      notebookFile.writeAsStringSync(corruptedContent, flush: true);

      final store = NotebookStore(storageDirectory: tempDir)..load();

      expect(store.entries, isEmpty);
      expect(store.lastCorruptionWarning, isNotNull);
      expect(
        store.lastCorruptionWarning,
        contains('Corrupt or truncated Fix Notebook detected'),
      );

      // Verify .bak file exists and preserves exact corrupted bytes
      final bakFiles = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('notebook.json.corrupt.') && f.path.endsWith('.bak'))
          .toList();
      expect(bakFiles.length, equals(1));
      expect(bakFiles.first.readAsStringSync(), equals(corruptedContent));
    });
  });
}
