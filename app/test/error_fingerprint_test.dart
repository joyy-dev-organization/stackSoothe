import 'package:flutter_test/flutter_test.dart';
import 'package:stacksoothe/utils/error_fingerprint.dart';

void main() {
  group('ErrorFingerprint & FIPS 180-4 SHA-256', () {
    test('sha256Hex matches official NIST FIPS 180-4 test vectors', () {
      expect(
        sha256Hex(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        sha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test(
        'canonicalizeErrorSignature normalizes timestamps, hex addresses, and line:col while preserving package and symbol distinctions',
        () {
      const logA = '''
2026-10-24T12:00:01.123Z RenderFlex overflowed by 42 pixels on the right.
#0      RenderFlex.performLayout (package:flutter/src/rendering/flex.dart:912:14)
#1      HomeScreen.build (package:my_app/screens/home_screen.dart:48:9)
Address: 0x00007ff81234abcd
''';

      const logB = '''
2026-10-24T16:45:59.999Z   RenderFlex overflowed by 42 pixels on the right.
#0   RenderFlex.performLayout (package:flutter/src/rendering/flex.dart:950:22)
#1   HomeScreen.build (package:my_app/screens/home_screen.dart:112:3)
Address: 0x00007ff89999efef
''';

      const differentPackageLog = '''
2026-10-24T16:45:59.999Z RenderFlex overflowed by 42 pixels on the right.
#0      RenderFlex.performLayout (package:flutter/src/rendering/flex.dart:950:22)
#1      SettingsScreen.build (package:other_app/screens/settings_screen.dart:112:3)
Address: 0x00007ff89999efef
''';

      final fpA = ErrorFingerprint.compute(
        errorLog: logA,
        codeContext: 'Row(children: [Text("Hello")])',
        projectContext: 'my_app',
        runtimeContext: 'Flutter 3.24 / Windows',
      );
      final fpB = ErrorFingerprint.compute(
        errorLog: logB,
        codeContext: 'Row(children: [Text("Hello")])',
        projectContext: 'my_app',
        runtimeContext: 'Flutter 3.24 / Windows',
      );
      final fpDiffPkg = ErrorFingerprint.compute(
        errorLog: differentPackageLog,
        codeContext: 'Row(children: [Text("Hello")])',
        projectContext: 'my_app',
        runtimeContext: 'Flutter 3.24 / Windows',
      );

      expect(fpA.errorSignatureHash, equals(fpB.errorSignatureHash));
      expect(fpA.compositeExactKey, equals(fpB.compositeExactKey));
      expect(fpA.errorSignatureHash, isNot(equals(fpDiffPkg.errorSignatureHash)));
    });

    test(
        'changed source code or project/runtime context changes compositeExactKey while keeping errorSignatureHash',
        () {
      const errorLog =
          'LateInitializationError: Field \'controller\' has not been initialized.';

      final baseFp = ErrorFingerprint.compute(
        errorLog: errorLog,
        codeContext: 'late final TextEditingController controller;',
        projectContext: 'checkout_app',
        runtimeContext: 'Flutter 3.24 / Dart 3.5',
      );

      final changedCodeFp = ErrorFingerprint.compute(
        errorLog: errorLog,
        codeContext: 'late TextEditingController controller; // edited',
        projectContext: 'checkout_app',
        runtimeContext: 'Flutter 3.24 / Dart 3.5',
      );

      final changedRuntimeFp = ErrorFingerprint.compute(
        errorLog: errorLog,
        codeContext: 'late final TextEditingController controller;',
        projectContext: 'checkout_app',
        runtimeContext: 'Flutter 3.27 / Dart 3.6',
      );

      final changedProjectFp = ErrorFingerprint.compute(
        errorLog: errorLog,
        codeContext: 'late final TextEditingController controller;',
        projectContext: 'admin_portal',
        runtimeContext: 'Flutter 3.24 / Dart 3.5',
      );

      expect(baseFp.errorSignatureHash, equals(changedCodeFp.errorSignatureHash));
      expect(baseFp.sourceContextHash, isNot(equals(changedCodeFp.sourceContextHash)));
      expect(baseFp.compositeExactKey, isNot(equals(changedCodeFp.compositeExactKey)));

      expect(baseFp.errorSignatureHash, equals(changedRuntimeFp.errorSignatureHash));
      expect(baseFp.runtimeContextHash, isNot(equals(changedRuntimeFp.runtimeContextHash)));
      expect(baseFp.compositeExactKey, isNot(equals(changedRuntimeFp.compositeExactKey)));

      expect(baseFp.runtimeContextHash, isNot(equals(changedProjectFp.runtimeContextHash)));
      expect(baseFp.compositeExactKey, isNot(equals(changedProjectFp.compositeExactKey)));
    });
  });
}
