import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stacksoothe/main.dart';

void main() {
  testWidgets('StackSootheApp launches and displays workspace title and controls',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const StackSootheApp());
    await tester.pumpAndSettle();

    // Verify workspace branding and navigation exist on desktop layout
    expect(find.text('StackSoothe'), findsWidgets);
    expect(find.text('Diagnose'), findsWidgets);
    expect(find.text('ERROR LOG'), findsWidgets);
    expect(find.text('SOURCE CONTEXT'), findsWidgets);
  });
}
