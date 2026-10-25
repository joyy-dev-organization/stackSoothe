import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stacksoothe/main.dart';
import 'package:stacksoothe/services/notebook_store.dart';
import 'package:stacksoothe/services/settings_store.dart';

void main() {
  testWidgets(
    'StackSootheApp launches and displays workspace title and controls',
    (WidgetTester tester) async {
      final tempDir = Directory.systemTemp.createTempSync('stacksoothe_smoke_');
      addTearDown(() {
        try {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        } catch (_) {}
      });

      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        StackSootheApp(
          notebookStore: NotebookStore(storageDirectory: tempDir),
          settingsStore: SettingsStore(storageDirectory: tempDir),
        ),
      );
      await tester.pumpAndSettle();

      // Verify workspace branding and navigation exist on desktop layout
      expect(find.text('StackSoothe'), findsWidgets);
      expect(find.text('Diagnose'), findsWidgets);
      expect(find.text('ERROR LOG'), findsWidgets);
      expect(find.text('SOURCE CONTEXT'), findsWidgets);
    },
  );
}
