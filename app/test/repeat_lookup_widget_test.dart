import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stacksoothe/main.dart';
import 'package:stacksoothe/models/app_settings.dart';
import 'package:stacksoothe/models/diagnosis_result.dart';
import 'package:stacksoothe/services/diagnosis_client.dart';
import 'package:stacksoothe/services/notebook_store.dart';
import 'package:stacksoothe/services/settings_store.dart';

DiagnosisResult _fakeLocalModelDiagnosis() {
  return const DiagnosisResult(
    title: 'RenderFlex horizontal overflow in Row',
    severity: 'Medium',
    confidence: 'High (91%)',
    summary: 'Row children exceed horizontal width because text is unbounded.',
    likelyCause: 'Expanded is missing around the variable-length Text widget.',
    steps: [
      'Wrap Text(longMessage) in Expanded.',
      'Re-test with flutter test.',
    ],
    verification: [
      'Confirm the yellow/black overflow stripe disappears on narrow widths.',
    ],
    codeExample:
        'Row(children: [const Icon(Icons.info), Expanded(child: Text(longMessage))])',
    modelName: 'llama3.2:latest',
    promptVersion: 'v1.0.0',
    isDemo: false,
  );
}

void main() {
  group('M2 Repeat-Error Lookup & Verification Workflow Widget Tests', () {
    testWidgets(
      'Save starts UNVERIFIED (S3), user marks VERIFIED, exact repeat makes 0 model calls (S1), changed context flags stale similar match (S2), and relaunch preserves state',
      (WidgetTester tester) async {
        final tempDir = Directory.systemTemp.createTempSync(
          'stacksoothe_m2_widget_',
        );
        addTearDown(() {
          try {
            if (tempDir.existsSync()) {
              tempDir.deleteSync(recursive: true);
            }
          } catch (_) {}
        });

        tester.view.physicalSize = const Size(1440, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final client = DiagnosisClient(
          customHandler:
              ({
                required String errorLog,
                required String sourceCode,
                required String model,
              }) async {
                return _fakeLocalModelDiagnosis();
              },
        );

        final notebookStore = NotebookStore(storageDirectory: tempDir);
        final settingsStore = SettingsStore(storageDirectory: tempDir);
        settingsStore.save(
          const AppSettings(
            serviceUrl: 'http://127.0.0.1:11435',
            model: 'llama3.2:latest',
            useLocalAi: true,
            projectContext: 'checkout-mobile',
            runtimeContext: 'Flutter 3.24.0 / Dart 3.5.0',
          ),
        );

        await tester.pumpWidget(
          StackSootheApp(
            notebookStore: notebookStore,
            settingsStore: settingsStore,
            diagnosisClient: client,
          ),
        );
        await tester.pumpAndSettle();

        // Enter error log and source snippet (project/runtime loaded from SettingsStore)
        await tester.enterText(
          find.byKey(const Key('error_log_field')),
          'A RenderFlex overflowed by 48 pixels on the right.\n#0 RenderFlex.performLayout (package:flutter/src/rendering/flex.dart:912:12)',
        );
        await tester.enterText(
          find.byKey(const Key('source_context_field')),
          'Row(children: [Icon(Icons.info), Text(longMessage)])',
        );
        await tester.pumpAndSettle();

        // 1. First diagnosis invokes the local model client once (invocationCount == 1)
        expect(client.invocationCount, equals(0));
        await tester.tap(find.byKey(const Key('diagnose_button')));
        await tester.pumpAndSettle();

        expect(client.invocationCount, equals(1));
        expect(
          find.text('RenderFlex horizontal overflow in Row'),
          findsOneWidget,
        );

        // Save diagnosis to Fix Notebook -> starts UNVERIFIED (S3)
        final saveButton = find.byKey(const Key('save_to_notebook_button'));
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('status_unverified_badge')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('status_verified_badge')), findsNothing);

        // User enters verification command/outcome and explicitly clicks Mark Verified
        await tester.enterText(
          find.byKey(const Key('verification_note_field')),
          'flutter test test/checkout_row_test.dart (passed)',
        );
        final markVerifiedBtn = find.byKey(const Key('mark_verified_button'));
        await tester.ensureVisible(markVerifiedBtn);
        await tester.tap(markVerifiedBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('status_verified_badge')), findsOneWidget);

        // 2. Exact-match repeat with identical error + source + project + runtime makes 0 new model calls (S1)
        final diagnoseBtn = find.byKey(const Key('diagnose_button'));
        await tester.ensureVisible(diagnoseBtn);
        await tester.tap(diagnoseBtn);
        await tester.pumpAndSettle();

        expect(
          client.invocationCount,
          equals(1),
        ); // Still 1! 0 new model requests!
        expect(find.byKey(const Key('recalled_exact_banner')), findsOneWidget);
        expect(find.byKey(const Key('status_verified_badge')), findsOneWidget);

        // 3. Change source code snippet -> must NOT silently reuse exact match; flags as potentially stale (S2)
        await tester.enterText(
          find.byKey(const Key('source_context_field')),
          'Row(children: [Icon(Icons.warning), Text(differentMessage), Spacer()])',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(diagnoseBtn);
        await tester.tap(diagnoseBtn);
        await tester.pumpAndSettle();

        // Still 0 new model calls while presenting the similar match review gate
        expect(client.invocationCount, equals(1));
        expect(
          find.byKey(const Key('similar_match_review_card')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('recalled_exact_banner')), findsNothing);

        // User clicks Review Similar Past Fix (Marked Stale)
        final reviewSimilarBtn = find.byKey(const Key('review_similar_button'));
        await tester.ensureVisible(reviewSimilarBtn);
        await tester.tap(reviewSimilarBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('stale_similar_banner')), findsOneWidget);
        expect(
          find.byKey(const Key('status_context_mismatch_badge')),
          findsOneWidget,
        );

        // 4. Relaunch with brand-new store instances on same tempDir -> reloads persisted entry & settings
        final relaunchedNotebookStore = NotebookStore(
          storageDirectory: tempDir,
        );
        final relaunchedSettingsStore = SettingsStore(
          storageDirectory: tempDir,
        );

        await tester.pumpWidget(
          StackSootheApp(
            key: const ValueKey('relaunched_app'),
            notebookStore: relaunchedNotebookStore,
            settingsStore: relaunchedSettingsStore,
            diagnosisClient: client,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Fix Notebook (1)'), findsWidgets);
        await tester.tap(find.byKey(const Key('open_notebook_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('RenderFlex horizontal overflow in Row'),
          findsOneWidget,
        );
        expect(find.text('VERIFIED'), findsOneWidget);
      },
    );

    testWidgets(
      'Corrupted notebook.json displays recoverable warning banner on startup',
      (WidgetTester tester) async {
        final tempDir = Directory.systemTemp.createTempSync(
          'stacksoothe_m2_corrupt_widget_',
        );
        addTearDown(() {
          try {
            if (tempDir.existsSync()) {
              tempDir.deleteSync(recursive: true);
            }
          } catch (_) {}
        });

        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final notebookFile = File(
          '${tempDir.path}${Platform.pathSeparator}notebook.json',
        );
        notebookFile.writeAsStringSync('{broken_json: [1, 2');

        await tester.pumpWidget(
          StackSootheApp(
            notebookStore: NotebookStore(storageDirectory: tempDir),
            settingsStore: SettingsStore(storageDirectory: tempDir),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('corruption_warning_banner')),
          findsOneWidget,
        );
      },
    );
  });
}
