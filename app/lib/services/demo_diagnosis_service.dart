import '../models/diagnosis_result.dart';

class DemoDiagnosisService {
  Future<DiagnosisResult> diagnose({
    required String errorLog,
    required String sourceCode,
  }) async {
    // A short delay makes the prototype feel like a real analysis flow.
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final text = '$errorLog\n$sourceCode'.toLowerCase();

    if (text.contains('buildcontext') ||
        text.contains('async gap') ||
        text.contains('deactivated widget')) {
      return const DiagnosisResult(
        title: 'BuildContext used across an async gap',
        severity: 'medium',
        summary:
            'An asynchronous operation may finish after the widget has been removed from the widget tree. Using its BuildContext at that point can trigger an analyzer warning or a runtime problem.',
        likelyCause:
            'The code awaits a Future and then uses context without checking whether the State is still mounted.',
        confidence: 'High',
        steps: [
          'After the await, check whether the State is still mounted before using context.',
          'If the widget is no longer mounted, return early instead of navigating or showing a SnackBar.',
          'Keep the mounted check close to the first context access after the asynchronous gap.',
        ],
        verification: [
          'Run flutter analyze and confirm the use_build_context_synchronously warning is gone.',
          'Trigger the action, navigate away while it is waiting, and confirm no exception occurs.',
        ],
        codeExample:
            'Future<void> saveProfile() async {\n  await repository.saveProfile();\n  if (!mounted) return;\n  Navigator.of(context).pop();\n}',
      );
    }

    if (text.contains('lateinitializationerror') ||
        text.contains('late initialization')) {
      return const DiagnosisResult(
        title: 'A late variable was read before initialization',
        severity: 'high',
        summary:
            'Dart throws LateInitializationError when a non-nullable late variable is accessed before a value has been assigned.',
        likelyCause:
            'The variable is declared late, but an initialization path did not run before the first read. This can happen when initialization is delayed or skipped by a branch.',
        confidence: 'High',
        steps: [
          'Find the variable named in the stack trace and search for its declaration and every assignment.',
          'Ensure initialization completes before the first read, including error and loading paths.',
          'Where appropriate, use a nullable type or initialize the variable at declaration instead of using late.',
        ],
        verification: [
          'Repeat the action from a fresh app launch, not only after a hot reload.',
          'Test the path where the value may be missing or loading has not completed.',
        ],
        codeExample:
            '// Prefer a safe initial value when one exists.\nString displayName = \'\';\n\n// Or explicitly model the uninitialized state.\nString? displayName;',
      );
    }

    if (text.contains('null check operator') ||
        text.contains('null check operator used on a null value') ||
        text.contains('null value')) {
      return const DiagnosisResult(
        title: 'A null value was force-unwrapped',
        severity: 'high',
        summary:
            'The `!` null-check operator was applied to a value that was null at runtime. The stack trace should help locate the expression that made this assumption.',
        likelyCause:
            'The code assumes a value exists, but the current state or API response allows it to be absent.',
        confidence: 'Medium',
        steps: [
          'Use the first stack-trace line that points to your own Dart file to locate the force unwrap.',
          'Inspect where the value is assigned, including empty API responses and first-launch state.',
          'Handle the missing-value case explicitly with a guard, a fallback, or a nullable UI state.',
        ],
        verification: [
          'Test with an empty or missing value as well as with the normal successful response.',
          'Confirm the UI still behaves correctly while data is loading or unavailable.',
        ],
        codeExample:
            '// Instead of: final name = user!.name;\nif (user == null) {\n  return const Text(\'User not available\');\n}\nreturn Text(user.name);',
      );
    }

    if (text.contains('renderflex') || text.contains('overflowed by')) {
      return const DiagnosisResult(
        title: 'A RenderFlex overflowed its available space',
        severity: 'medium',
        summary:
            'A Row or Column has children whose combined layout size is larger than the space available in that direction.',
        likelyCause:
            'One or more children are taking their full intrinsic width or height instead of adapting to the constraints provided by the parent.',
        confidence: 'High',
        steps: [
          'Find the highlighted Row or Column from the Flutter error details.',
          'For a Row, wrap the flexible text or content area in Expanded or Flexible where appropriate.',
          'For content that must scroll, use a scrollable parent rather than forcing every child to fit.',
        ],
        verification: [
          'Test with a narrow desktop window and with the longest expected text.',
          'Check that the yellow-and-black overflow indicator no longer appears.',
        ],
        codeExample:
            'Row(\n  children: [\n    const Icon(Icons.info_outline),\n    const SizedBox(width: 8),\n    Expanded(child: Text(longDescription)),\n  ],\n)',
      );
    }

    if (text.contains('firebaseexception') ||
        text.contains('configuration_not_found') ||
        text.contains('no firebase app')) {
      return const DiagnosisResult(
        title: 'Firebase setup or app configuration may be missing',
        severity: 'medium',
        summary:
            'This error pattern often means the Firebase app or the requested Firebase service has not been configured for the current platform or build.',
        likelyCause:
            'The app may be missing generated Firebase options, using the wrong Firebase project configuration, or initializing a service before Firebase.initializeApp completes.',
        confidence: 'Medium',
        steps: [
          'Confirm Firebase is initialized before any Firebase service is used.',
          'Check that the configuration matches the active application ID and target platform.',
          'Re-run the FlutterFire configuration flow if the application or Firebase project changed.',
        ],
        verification: [
          'Run the app on the affected platform after a clean rebuild.',
          'Confirm the Firebase initialization future completes before accessing the service.',
        ],
        codeExample:
            'await Firebase.initializeApp(\n  options: DefaultFirebaseOptions.currentPlatform,\n);',
      );
    }

    return const DiagnosisResult(
      title: 'Start with the first actionable error',
      severity: 'medium',
      summary:
          'The demo recognizer could not confidently map this input to one of its built-in examples. Real local AI mode can analyze a wider range of Flutter and Dart errors.',
      likelyCause:
          'The pasted text may omit the first exception line, the relevant stack-trace frame, or the code around the failing operation.',
      confidence: 'Low',
      steps: [
        'Copy the complete error starting from the first exception or analyzer message.',
        'Include the first stack-trace frame that points to your own lib/ directory.',
        'Add the relevant widget or function in the source-code context box, then diagnose again.',
      ],
      verification: [
        'Check that the suggested cause points to a line in your own code.',
        'Make one change at a time and rerun the original action or test.',
      ],
    );
  }
}
