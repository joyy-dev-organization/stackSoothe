import 'package:flutter_test/flutter_test.dart';
import 'package:stacksoothe/models/diagnosis_result.dart';
import 'package:stacksoothe/services/diagnosis_client.dart';

void main() {
  group('DiagnosisResult.fromEnvelope', () {
    test('parses a valid envelope correctly', () {
      final envelope = {
        'success': true,
        'data': {
          'title': 'RenderFlex overflowed',
          'severity': 'low',
          'summary': 'A Row has exceeded horizontal space.',
          'likely_cause': 'Children in Row are unconstrained.',
          'confidence': 'High',
          'steps': ['Wrap child with Expanded'],
          'verification': ['Check layout in debugger'],
          'code_example': 'Expanded(child: Text("long"))',
        },
        'meta': {
          'model': 'qwen2.5-coder:3b',
          'raw_valid': true,
          'repaired': false,
          'duration_ms': 1200,
        },
      };

      final result = DiagnosisResult.fromEnvelope(envelope);
      expect(result.title, 'RenderFlex overflowed');
      expect(result.severity, 'low');
      expect(result.modelName, 'qwen2.5-coder:3b');
      expect(result.isDemo, isFalse);
    });

    test('annotates auto-repaired diagnoses in modelName', () {
      final envelope = {
        'success': true,
        'data': {
          'title': 'Repaired Diagnosis',
          'severity': 'medium',
          'summary': 'Recovered via repair prompt.',
          'likely_cause': 'Schema was fixed.',
          'confidence': 'Medium',
          'steps': ['Step one'],
          'verification': ['Verify one'],
          'code_example': '',
        },
        'meta': {
          'model': 'qwen2.5-coder:3b',
          'raw_valid': false,
          'repaired': true,
          'duration_ms': 2500,
        },
      };

      final result = DiagnosisResult.fromEnvelope(envelope);
      expect(result.modelName, contains('(auto-repaired)'));
    });

    test('throws Exception with server message on failure envelope', () {
      final envelope = {
        'success': false,
        'error': {
          'code': 'SCHEMA_VALIDATION_ERROR',
          'message': 'Model output failed schema validation.',
        },
        'meta': {
          'model': 'qwen2.5-coder:3b',
          'raw_valid': false,
          'repaired': false,
          'duration_ms': 500,
        },
      };

      expect(
        () => DiagnosisResult.fromEnvelope(envelope),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Model output failed schema validation.'),
          ),
        ),
      );
    });

    test('propagates OLLAMA_TIMEOUT error message correctly', () {
      final envelope = {
        'success': false,
        'error': {
          'code': 'OLLAMA_TIMEOUT',
          'message': 'Ollama diagnosis timed out after 120000ms',
        },
        'meta': {
          'model': 'qwen3:1.7b',
          'raw_valid': false,
          'repaired': false,
          'duration_ms': 120000,
        },
      };

      expect(
        () => DiagnosisResult.fromEnvelope(envelope),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Ollama diagnosis timed out after 120000ms'),
          ),
        ),
      );
    });

    test('propagates OLLAMA_UNREACHABLE error message correctly', () {
      final envelope = {
        'success': false,
        'error': {
          'code': 'OLLAMA_UNREACHABLE',
          'message': 'Could not reach Ollama at http://127.0.0.1:11434',
        },
        'meta': {
          'model': 'qwen3:1.7b',
          'raw_valid': false,
          'repaired': false,
          'duration_ms': 15,
        },
      };

      expect(
        () => DiagnosisResult.fromEnvelope(envelope),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Could not reach Ollama at http://127.0.0.1:11434'),
          ),
        ),
      );
    });
  });

  group('DiagnosisClient loopback security and cancellation', () {
    test('rejects non-loopback base URL with ArgumentError', () async {
      final client = DiagnosisClient(baseUrl: 'https://remote-ai.example.com');
      expect(
        () => client.diagnose(errorLog: 'Test error', sourceCode: ''),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('Private mode requires a loopback address'),
          ),
        ),
      );
    });

    test('cancelPendingRequest does not crash when no request in flight', () {
      final client = DiagnosisClient();
      expect(client.cancelPendingRequest, returnsNormally);
    });
  });
}
