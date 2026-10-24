import 'package:flutter_test/flutter_test.dart';
import 'package:stacksoothe/services/demo_diagnosis_service.dart';

void main() {
  group('DemoDiagnosisService', () {
    final service = DemoDiagnosisService();

    test('recognizes BuildContext async-gap errors', () async {
      final result = await service.diagnose(
        errorLog: "Don't use BuildContext across async gaps",
        sourceCode: 'Navigator.of(context).pop();',
      );

      expect(result.title, contains('BuildContext'));
      expect(result.steps, isNotEmpty);
      expect(result.isDemo, isTrue);
    });

    test('recognizes RenderFlex overflow errors', () async {
      final result = await service.diagnose(
        errorLog: 'A RenderFlex overflowed by 20 pixels on the right.',
        sourceCode: 'Row(children: [Text(longText)])',
      );

      expect(result.title, contains('RenderFlex'));
      expect(result.codeExample, contains('Expanded'));
    });

    test('returns a useful fallback for unknown errors', () async {
      final result = await service.diagnose(
        errorLog: 'Unexpected demo error from test fixture',
        sourceCode: '',
      );

      expect(result.confidence, 'Low');
      expect(result.verification, isNotEmpty);
    });
  });
}
