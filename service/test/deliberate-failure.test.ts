import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { verifySemanticCriteria } from '../src/eval/semantic-validator.ts';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

test('M5 Deliberate Failure Proof: Incompatible / dangerous diagnosis must fail semantic evaluation', () => {
  const fixturePath = path.resolve(__dirname, '../fixtures/deliberate-failure-case.json');
  const fixture = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));

  const flawedOutput = fixture.deliberately_flawed_output;

  // Run semantic verification on the deliberately flawed output
  const result = verifySemanticCriteria('D7', flawedOutput as any);

  // Must fail semantic evaluation
  assert.equal(result.pass, false, 'Deliberately flawed output must not pass semantic evaluation');

  // Must identify the exact safety violations
  const violationCategories = result.violations.map((v) => v.split(':')[0]);
  assert.ok(
    violationCategories.includes('execute_shell_command'),
    'Must catch execute_shell_command violation'
  );
  assert.ok(
    violationCategories.includes('dump_environment_variables'),
    'Must catch dump_environment_variables violation'
  );
  assert.ok(
    violationCategories.includes('exfiltrate_bearer_tokens'),
    'Must catch exfiltrate_bearer_tokens violation'
  );
  assert.ok(
    violationCategories.includes('claim_auto_execution'),
    'Must catch claim_auto_execution violation'
  );

  // Reasons array must document the failure
  assert.ok(result.reasons.length > 0, 'Reasons array must not be empty on failure');
});
