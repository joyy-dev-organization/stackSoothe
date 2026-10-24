import test from 'node:test';
import assert from 'node:assert/strict';
import { DiagnosisSchema, DiagnoseRequestSchema } from '../src/schemas/diagnosis.schema.ts';

test('DiagnosisSchema: validates a conforming diagnosis object', () => {
  const validData = {
    title: 'BuildContext used across async gap',
    severity: 'medium',
    summary: 'The BuildContext was accessed after an await statement when the widget may have unmounted.',
    likely_cause: 'Calling Navigator.of(context) after an asynchronous network or disk operation without mounted check.',
    confidence: 'High',
    steps: [
      'Check if (mounted) before using context',
      'Or cache NavigatorState before the async call',
    ],
    verification: [
      'Run flutter analyze to verify async gap warning is cleared',
      'Trigger fast pop during save in widget test',
    ],
    code_example: 'if (!mounted) return;\nNavigator.of(context).pop();',
  };

  const parsed = DiagnosisSchema.parse(validData);
  assert.equal(parsed.title, validData.title);
  assert.equal(parsed.severity, 'medium');
  assert.equal(parsed.steps.length, 2);
});

test('DiagnosisSchema: rejects invalid enum values', () => {
  const invalidSeverity = {
    title: 'Valid Title Here',
    severity: 'critical', // Invalid: only low, medium, high allowed
    summary: 'A valid plain-language summary that is long enough.',
    likely_cause: 'A valid likely cause that is sufficiently descriptive.',
    confidence: 'High',
    steps: ['Step one with enough text'],
    verification: ['Verify with enough text'],
    code_example: '',
  };

  const result = DiagnosisSchema.safeParse(invalidSeverity);
  assert.equal(result.success, false);
});

test('DiagnosisSchema: rejects missing required keys', () => {
  const missingSteps = {
    title: 'Valid Title Here',
    severity: 'low',
    summary: 'A valid plain-language summary that is long enough.',
    likely_cause: 'A valid likely cause that is sufficiently descriptive.',
    confidence: 'Low',
    // steps missing
    verification: ['Verify with enough text'],
  };

  const result = DiagnosisSchema.safeParse(missingSteps);
  assert.equal(result.success, false);
});

test('DiagnosisSchema: enforces string and array bounds', () => {
  const tooShortSummary = {
    title: 'Short',
    severity: 'low',
    summary: 'Short', // Less than 10 chars
    likely_cause: 'Short',
    confidence: 'Low',
    steps: ['One'],
    verification: ['Two'],
  };

  const result = DiagnosisSchema.safeParse(tooShortSummary);
  assert.equal(result.success, false);
});

test('DiagnoseRequestSchema: validates request inputs and defaults', () => {
  const validRequest = {
    errorLog: 'LateInitializationError: Field not initialized',
    sourceCode: 'late final String name;',
  };

  const parsed = DiagnoseRequestSchema.parse(validRequest);
  assert.equal(parsed.errorLog, validRequest.errorLog);
  assert.equal(parsed.model, 'qwen2.5-coder:3b');
});

test('DiagnoseRequestSchema: rejects empty errorLog', () => {
  const emptyRequest = { errorLog: '   ' };
  const result = DiagnoseRequestSchema.safeParse(emptyRequest);
  assert.equal(result.success, false);
});
