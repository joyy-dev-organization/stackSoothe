import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stacksoothe/main.dart';
import 'package:stacksoothe/models/app_settings.dart';
import 'package:stacksoothe/services/notebook_store.dart';
import 'package:stacksoothe/services/settings_store.dart';

void main() {
  group(
    'M4 Loopback Security, Explicit Demo Labels, Window Usability & Keyboard Tests',
    () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync(
          'stacksoothe_m4_sec_test_',
        );
      });

      tearDown(() {
        try {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        } catch (_) {}
      });

      test(
        'AppSettings strictly accepts only loopback URLs and sanitizes non-loopback',
        () {
          expect(AppSettings.isLoopbackUrl('http://127.0.0.1:11435'), isTrue);
          expect(AppSettings.isLoopbackUrl('http://localhost:11435'), isTrue);
          expect(AppSettings.isLoopbackUrl('http://[::1]:11435'), isTrue);

          // Rejects WAN / remote domains
          expect(
            AppSettings.isLoopbackUrl('https://api.external.com'),
            isFalse,
          );
          expect(
            AppSettings.isLoopbackUrl('http://192.168.1.100:11434'),
            isFalse,
          );
          expect(
            AppSettings.isLoopbackUrl('http://localhost.attacker.com'),
            isFalse,
          );

          // fromJson automatically falls back to safe 127.0.0.1 if a non-loopback URL was serialized
          final settings = AppSettings.fromJson({
            'service_url': 'http://evil.remote-ai.com:11435',
            'model': 'qwen2.5-coder:3b',
          });
          expect(settings.serviceUrl, equals('http://127.0.0.1:11435'));
        },
      );

      testWidgets(
        'Criterion 4: Demo mode visibly renders RULE-BASED EXAMPLE (NOT AI INFERENCE) badge',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1280, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final notebookStore = NotebookStore(storageDirectory: tempDir);
          final settingsStore = SettingsStore(storageDirectory: tempDir);
          settingsStore.save(const AppSettings(useLocalAi: false)); // Demo mode

          await tester.pumpWidget(
            StackSootheApp(
              notebookStore: notebookStore,
              settingsStore: settingsStore,
            ),
          );
          await tester.pumpAndSettle();

          // Run diagnosis in demo mode
          final diagnoseBtn = find.byKey(const Key('diagnose_button'));
          await tester.ensureVisible(diagnoseBtn);
          await tester.tap(diagnoseBtn);
          await tester.pumpAndSettle();

          // Verify explicit RULE-BASED EXAMPLE (NOT AI INFERENCE) labels
          expect(
            find.byKey(const Key('demo_rule_based_badge')),
            findsOneWidget,
          );
          expect(find.text('RULE-BASED · NOT AI'), findsOneWidget);
          expect(
            find.text('RULE-BASED EXAMPLE (NOT AI INFERENCE)'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'Criterion 5: Window responsiveness at 1280x720 and narrow 800x600 with zero overflow',
        (WidgetTester tester) async {
          final notebookStore = NotebookStore(storageDirectory: tempDir);
          final settingsStore = SettingsStore(storageDirectory: tempDir);

          // 1. Test 1280x720 (standard desktop window)
          tester.view.physicalSize = const Size(1280, 720);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            StackSootheApp(
              notebookStore: notebookStore,
              settingsStore: settingsStore,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('StackSoothe'), findsWidgets);
          expect(find.text('Diagnose'), findsWidgets);

          // 2. Test narrow window (800x600)
          tester.view.physicalSize = const Size(800, 600);
          await tester.pumpWidget(
            StackSootheApp(
              notebookStore: notebookStore,
              settingsStore: settingsStore,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // On narrow screen, compact topbar and main heading render cleanly without overflow
          expect(find.text('Diagnose'), findsWidgets);
          expect(find.text("Let’s untangle that error."), findsOneWidget);
        },
      );

      testWidgets(
        'Criterion 5: Keyboard shortcut Ctrl+Enter triggers diagnosis',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1280, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final notebookStore = NotebookStore(storageDirectory: tempDir);
          final settingsStore = SettingsStore(storageDirectory: tempDir);
          settingsStore.save(const AppSettings(useLocalAi: false));

          await tester.pumpWidget(
            StackSootheApp(
              notebookStore: notebookStore,
              settingsStore: settingsStore,
            ),
          );
          await tester.pumpAndSettle();

          // Focus error log input
          final errorField = find.byKey(const Key('error_log_field'));
          await tester.ensureVisible(errorField);
          await tester.tap(errorField);
          await tester.pumpAndSettle();

          // Trigger Ctrl + Enter
          await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
          await tester.pumpAndSettle();

          // Result appears
          expect(
            find.byKey(const Key('demo_rule_based_badge')),
            findsOneWidget,
          );
        },
      );
    },
  );
}
