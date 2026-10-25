import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stacksoothe/main.dart';
import 'package:stacksoothe/models/app_settings.dart';
import 'package:stacksoothe/models/diagnosis_result.dart';
import 'package:stacksoothe/services/diagnosis_client.dart';
import 'package:stacksoothe/services/notebook_store.dart';
import 'package:stacksoothe/services/settings_store.dart';

DiagnosisResult _fakeDiagnosisResult({
  String title = 'Test Diagnosis',
  String model = 'qwen2.5-coder:3b',
}) {
  return DiagnosisResult(
    title: title,
    severity: 'low',
    summary: 'A test explanation of the issue.',
    likelyCause: 'A test cause.',
    confidence: 'High',
    steps: const ['Step 1', 'Step 2'],
    verification: const ['Verify 1'],
    codeExample: '',
    modelName: model,
    promptVersion: 'v1.0.0',
    isDemo: false,
  );
}

void main() {
  group(
    'M4 Request State Machine, In-Flight Editing, Cancellation & Late Response Tests',
    () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('stacksoothe_m4_test_');
      });

      tearDown(() {
        try {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        } catch (_) {}
      });

      testWidgets(
        'Criterion 1: Source fields remain editable while request is pending; late response does not overwrite modified inputs',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1280, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final completer = Completer<DiagnosisResult>();
          final client = DiagnosisClient(
            customHandler:
                ({
                  required String errorLog,
                  required String sourceCode,
                  required String model,
                }) => completer.future,
          );

          final notebookStore = NotebookStore(storageDirectory: tempDir);
          final settingsStore = SettingsStore(storageDirectory: tempDir);
          settingsStore.save(
            const AppSettings(
              serviceUrl: 'http://127.0.0.1:11435',
              model: 'qwen2.5-coder:3b',
              useLocalAi: true,
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

          // 1. Enter initial error log and source code
          await tester.enterText(
            find.byKey(const Key('error_log_field')),
            'Original error log text A',
          );
          await tester.enterText(
            find.byKey(const Key('source_context_field')),
            'Original source code text A',
          );
          await tester.pumpAndSettle();

          // 2. Click Diagnose to start the in-flight request
          await tester.tap(find.byKey(const Key('diagnose_button')));
          await tester
              .pump(); // Request is now in-flight (waiting on completer)

          // Verify in-flight loading state and "Stop waiting — model may continue" button are active
          expect(find.byKey(const Key('stop_waiting_button')), findsOneWidget);

          // 3. EXACT TEST PATH required by Acceptance Criterion 1:
          // Verify source and error fields remain editable while request is pending!
          await tester.enterText(
            find.byKey(const Key('error_log_field')),
            'New edited error log text B (typed while diagnosing)',
          );
          await tester.enterText(
            find.byKey(const Key('source_context_field')),
            'New edited source code text B (typed while diagnosing)',
          );
          await tester.pump();

          // Confirm text changed in the UI while request was in-flight
          expect(
            find.text('New edited error log text B (typed while diagnosing)'),
            findsOneWidget,
          );
          expect(
            find.text('New edited source code text B (typed while diagnosing)'),
            findsOneWidget,
          );

          // 4. Now complete the delayed response from the snapshot
          completer.complete(
            _fakeDiagnosisResult(title: 'Diagnosis for original text A'),
          );
          await tester.pumpAndSettle();

          // 5. Late response must NOT overwrite user's edited inputs!
          expect(
            find.text('New edited error log text B (typed while diagnosing)'),
            findsOneWidget,
          );
          expect(
            find.text('New edited source code text B (typed while diagnosing)'),
            findsOneWidget,
          );
          // The detached snapshot banner alerts the developer that snapshot finished without clobbering editor
          expect(
            find.byKey(const Key('detached_snapshot_banner')),
            findsOneWidget,
          );
          expect(find.text('Diagnosis for original text A'), findsOneWidget);
        },
      );

      testWidgets(
        'Criterion 1: Clearing inputs while request is in-flight rejects late response and leaves workspace clear',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1280, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final completer = Completer<DiagnosisResult>();
          final client = DiagnosisClient(
            customHandler:
                ({
                  required String errorLog,
                  required String sourceCode,
                  required String model,
                }) => completer.future,
          );

          final notebookStore = NotebookStore(storageDirectory: tempDir);
          final settingsStore = SettingsStore(storageDirectory: tempDir);
          settingsStore.save(
            const AppSettings(
              serviceUrl: 'http://127.0.0.1:11435',
              model: 'qwen2.5-coder:3b',
              useLocalAi: true,
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

          await tester.enterText(
            find.byKey(const Key('error_log_field')),
            'Log to be cleared',
          );
          await tester.tap(find.byKey(const Key('diagnose_button')));
          await tester.pump();

          // While pending, click Clear inputs button
          await tester.tap(find.byKey(const Key('clear_inputs_button')));
          await tester.pumpAndSettle();

          // Workspace is clear
          final errorField = tester.widget<TextField>(
            find.byKey(const Key('error_log_field')),
          );
          expect(errorField.controller?.text, isEmpty);

          // Now complete the late response
          completer.complete(
            _fakeDiagnosisResult(title: 'Stale late response'),
          );
          await tester.pumpAndSettle();

          // Stale response must NOT appear and must NOT repopulate the cleared fields
          expect(find.text('Stale late response'), findsNothing);
          expect(find.byKey(const Key('empty_results_card')), findsOneWidget);
        },
      );

      testWidgets(
        'Criterion 3: Stop waiting cancels waiting state, ignores late response, and handles retry while busy gracefully',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1280, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final completer = Completer<DiagnosisResult>();
          var callCount = 0;

          final client = DiagnosisClient(
            customHandler:
                ({
                  required String errorLog,
                  required String sourceCode,
                  required String model,
                }) async {
                  callCount++;
                  if (callCount == 1) {
                    return completer.future; // delayed first call
                  }
                  // Second call: simulate backend returning busy (HTTP 429)
                  throw const ServiceBusyException(
                    'Another diagnosis request is currently in progress. StackSoothe operates single-concurrency without queuing.',
                  );
                },
          );

          final notebookStore = NotebookStore(storageDirectory: tempDir);
          final settingsStore = SettingsStore(storageDirectory: tempDir);
          settingsStore.save(
            const AppSettings(
              serviceUrl: 'http://127.0.0.1:11435',
              model: 'qwen2.5-coder:3b',
              useLocalAi: true,
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

          // 1. Start diagnosis
          await tester.enterText(
            find.byKey(const Key('error_log_field')),
            'RenderFlex overflow 32px',
          );
          await tester.tap(find.byKey(const Key('diagnose_button')));
          await tester.pump();

          // 2. Click "Stop waiting — model may continue"
          final stopBtn = find.byKey(const Key('stop_waiting_button'));
          expect(stopBtn, findsOneWidget);
          await tester.tap(stopBtn);
          await tester.pumpAndSettle();

          // Verify user stopped waiting and is no longer blocked by spinner
          expect(find.byKey(const Key('stop_waiting_button')), findsNothing);
          expect(find.byKey(const Key('diagnose_button')), findsOneWidget);
          expect(
            find.textContaining('Stopped waiting for diagnosis run'),
            findsOneWidget,
          );

          // 3. User immediately retries while backend is still busy (cancel -> retry path)
          await tester.tap(find.byKey(const Key('diagnose_button')));
          await tester.pumpAndSettle();

          // 4. Verify calm advisory banner is displayed for BUSY state with Retry action
          expect(find.byKey(const Key('busy_service_banner')), findsOneWidget);
          expect(find.byKey(const Key('retry_busy_button')), findsOneWidget);
          expect(
            find.textContaining(
              'Local service is currently busy completing a previous model request',
            ),
            findsOneWidget,
          );

          // 5. Late response from original run #1 resolves; must be completely ignored
          completer.complete(
            _fakeDiagnosisResult(title: 'Ignored Run 1 Result'),
          );
          await tester.pumpAndSettle();

          expect(find.text('Ignored Run 1 Result'), findsNothing);
        },
      );
    },
  );
}
