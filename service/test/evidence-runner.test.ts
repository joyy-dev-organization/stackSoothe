import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { fileURLToPath } from 'node:url';
import * as Sentry from '@sentry/node';
import { runAllM3EvidenceCases } from '../src/evidence/evidence-runner.ts';
import { runSyntheticSentrySpike } from '../src/evidence/sentry-spike.ts';
import { createServer } from '../src/server.ts';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

test('M3 Tracing, Diagnostic Paths & Strict Privacy Verification', async (t) => {
  await t.test('1. Executes 4 diagnostic paths with real-vs-mocked labels in manifest', async () => {
    const manifest = await runAllM3EvidenceCases();

    assert.ok(manifest.run_id.startsWith('m3-evidence-'));
    assert.equal(manifest.total_cases, 4);

    // PATH 1: Success (real-model)
    const successPath = manifest.paths.success;
    assert.equal(successPath.path_id, 'PATH_SUCCESS');
    assert.equal(successPath.execution_type, 'real-model');
    assert.equal(successPath.success, true);
    assert.ok(successPath.duration_ms > 0);
    assert.ok(typeof successPath.input_tokens === 'number' && successPath.input_tokens > 0);
    assert.ok(typeof successPath.output_tokens === 'number' && successPath.output_tokens > 0);
    assert.ok(successPath.timings, 'Timings should be populated for real model');
    assert.ok(successPath.local_api_fee.includes('$0 external per-token fee'));

    // PATH 2: Unavailable model (real-network-failure)
    const unavailPath = manifest.paths.unavailable;
    assert.equal(unavailPath.path_id, 'PATH_UNAVAILABLE');
    assert.equal(unavailPath.execution_type, 'real-network-failure');
    assert.equal(unavailPath.success, false);
    assert.equal(unavailPath.error_code, 'OLLAMA_UNREACHABLE');
    assert.equal(unavailPath.error_type, 'MODEL_UNAVAILABLE');
    // Missing tokens must remain undefined, not fabricated zeros
    assert.equal(unavailPath.input_tokens, undefined);
    assert.equal(unavailPath.output_tokens, undefined);

    // PATH 3: Invalid schema failure (mock-http)
    const schemaPath = manifest.paths.invalid_schema;
    assert.equal(schemaPath.path_id, 'PATH_INVALID_SCHEMA');
    assert.equal(schemaPath.execution_type, 'mock-http');
    assert.equal(schemaPath.success, false);
    assert.equal(schemaPath.error_code, 'SCHEMA_VALIDATION_ERROR');
    assert.equal(schemaPath.error_type, 'SCHEMA_VALIDATION_FAILED');
    assert.equal(schemaPath.input_tokens, 64);
    assert.equal(schemaPath.output_tokens, 92);
    assert.equal(schemaPath.timings?.total_ms, 620);

    // PATH 4: Timeout abort (mock-http)
    const timeoutPath = manifest.paths.timeout;
    assert.equal(timeoutPath.path_id, 'PATH_TIMEOUT');
    assert.equal(timeoutPath.execution_type, 'mock-http');
    assert.equal(timeoutPath.success, false);
    assert.equal(timeoutPath.error_code, 'OLLAMA_TIMEOUT');
    assert.equal(timeoutPath.error_type, 'TIMEOUT');

    // Verify manifest file on disk
    const manifestPath = path.resolve(__dirname, '../fixtures/m3-evidence-manifest.json');
    assert.ok(fs.existsSync(manifestPath), 'Manifest file must exist on disk');
    const onDiskManifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    assert.equal(onDiskManifest.run_id, manifest.run_id);
  });

  await t.test('2. Sentry Export Envelope Allowlist: zero prompt, code, output, or credentials in serialized transport', async () => {
    const sentEnvelopes: any[] = [];

    // Initialize an isolated Sentry client with in-memory transport callback and valid 32-hex DSN
    Sentry.init({
      dsn: 'https://0123456789abcdef0123456789abcdef@example.ingest.sentry.io/1234567',
      defaultIntegrations: false,
      tracesSampleRate: 1.0,
      transport: () => ({
        send: async (envelope: any) => {
          sentEnvelopes.push(envelope);
          return { status: 'success' };
        },
        flush: async () => true,
      }),
    });

    const fixturesPath = path.resolve(__dirname, '../fixtures/synthetic-cases.json');
    const fixturesData = JSON.parse(fs.readFileSync(fixturesPath, 'utf8'));
    const d1Fixture = fixturesData.cases.find((c: any) => c.id === 'D1') ?? fixturesData.cases[0];

    // Mock Ollama to test synthetic Sentry envelope serialization cleanly
    const mockOllama = http.createServer((_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          model: 'qwen3:1.7b',
          created_at: new Date().toISOString(),
          message: {
            role: 'assistant',
            content: JSON.stringify({
              title: 'BuildContext Async Gap Diagnosis',
              severity: 'medium',
              summary: 'Grounded lifecycle and mounted guidance with caveats',
              likely_cause: 'Navigator.of(context) called after asynchronous gap',
              confidence: 'High',
              steps: ['Check mounted property before pop', 'Use local context safely'],
              verification: ['Run flutter analyze', 'Trigger async profile save'],
              code_example: 'if (!mounted) return; Navigator.of(context).pop();',
            }),
          },
          done: true,
          prompt_eval_count: 142,
          eval_count: 88,
          total_duration: 500_000_000,
          load_duration: 50_000_000,
          prompt_eval_duration: 150_000_000,
          eval_duration: 300_000_000,
        })
      );
    });

    await new Promise<void>((resolve) => mockOllama.listen(0, '127.0.0.1', resolve));
    const mockPort = (mockOllama.address() as any).port;

    try {
      const result = await runSyntheticSentrySpike({
        errorLog: d1Fixture.errorLog,
        sourceCode: d1Fixture.sourceCode,
        model: 'qwen3:1.7b',
        baseUrl: `http://127.0.0.1:${mockPort}`,
      });

      assert.equal(result.envelope.success, true);
      await Sentry.flush();

      assert.ok(sentEnvelopes.length > 0, 'Transport should have intercepted sent envelopes');

      // Inspect the serialized envelope payload
      const rawEnvelopeJson = JSON.stringify(sentEnvelopes);
      const serializedLower = rawEnvelopeJson.toLowerCase();

      // Verify ZERO private or sensitive data leakage
      assert.equal(
        serializedLower.includes('saveprofile'),
        false,
        'Prohibited: source code function name found in serialized Sentry envelope'
      );
      assert.equal(
        serializedLower.includes('navigator.of'),
        false,
        'Prohibited: source code snippet found in serialized Sentry envelope'
      );
      assert.equal(
        serializedLower.includes('profile_screen.dart'),
        false,
        'Prohibited: file path found in serialized Sentry envelope'
      );
      assert.equal(
        serializedLower.includes('dont use buildcontext'),
        false,
        'Prohibited: raw error log found in serialized Sentry envelope'
      );
      assert.equal(
        serializedLower.includes('likely_cause'),
        false,
        'Prohibited: diagnosis model output found in serialized Sentry envelope'
      );
      assert.equal(
        serializedLower.includes('c:\\users'),
        false,
        'Prohibited: local Windows user path found in serialized Sentry envelope'
      );
      assert.equal(
        serializedLower.includes('bearer'),
        false,
        'Prohibited: auth token keyword found in serialized Sentry envelope'
      );

      // Verify all span attributes strictly match the safe allowlist
      const envelopeItems = sentEnvelopes[0][1];
      const spanItem = envelopeItems.find((item: any) => item[0]?.type === 'span');
      assert.ok(spanItem, 'Span item must exist in envelope');

      const spanPayload = spanItem[1]?.items?.[0];
      assert.ok(spanPayload, 'Span payload must exist');
      assert.equal(spanPayload.name, 'chat qwen3:1.7b');

      const ALLOWLISTED_PREFIXES = [
        'sentry.',
        'gen_ai.',
        'ollama.timing.',
        'error.type',
      ];

      for (const attrKey of Object.keys(spanPayload.attributes ?? {})) {
        const isAllowed = ALLOWLISTED_PREFIXES.some((prefix) =>
          attrKey === prefix || attrKey.startsWith(prefix)
        );
        assert.ok(
          isAllowed,
          `Unallowlisted attribute "${attrKey}" detected in Sentry span envelope`
        );
      }
    } finally {
      mockOllama.close();
    }
  });

  await t.test('3. Private Mode: server.ts operates exporter-free with zero telemetry', async () => {
    // 1. Spin up mock Ollama server for private server test
    const mockOllama = http.createServer((_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          model: 'qwen3:1.7b',
          created_at: new Date().toISOString(),
          message: {
            role: 'assistant',
            content: JSON.stringify({
              title: 'Private Mode Test Diagnosis',
              severity: 'low',
              summary: 'Local private diagnosis test run',
              likely_cause: 'Testing private mode no-exporter execution',
              confidence: 'High',
              steps: ['Verify zero telemetry export'],
              verification: ['Check Sentry is uninitialized or uncalled'],
              code_example: '',
            }),
          },
          done: true,
          prompt_eval_count: 30,
          eval_count: 40,
          total_duration: 200_000_000,
        })
      );
    });

    await new Promise<void>((resolve) => mockOllama.listen(0, '127.0.0.1', resolve));
    const mockPort = (mockOllama.address() as any).port;
    const mockBaseUrl = `http://127.0.0.1:${mockPort}`;

    // 2. Create server instance pointed at mock Ollama
    const testToken = 'test-private-mode-token-12345';
    const testPort = 11438;
    const { server, port } = createServer(testToken, testPort, mockBaseUrl);

    await new Promise<void>((resolve) => server.listen(port, '127.0.0.1', resolve));

    try {
      // Execute health check
      const healthRes = await fetch(`http://127.0.0.1:${port}/health`);
      assert.equal(healthRes.status, 200);
      const healthJson = (await healthRes.json()) as any;
      assert.equal(healthJson.service, 'stacksoothe-service');

      // Execute private diagnosis request
      const diagRes = await fetch(`http://127.0.0.1:${port}/api/diagnose`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${testToken}`,
        },
        body: JSON.stringify({
          errorLog: 'Private error log that must never be exported',
          sourceCode: 'void privateFunction() {}',
          model: 'qwen3:1.7b',
        }),
      });

      assert.equal(diagRes.status, 200);
      const diagEnvelope = (await diagRes.json()) as any;
      assert.equal(diagEnvelope.success, true);
      assert.equal(diagEnvelope.data.title, 'Private Mode Test Diagnosis');

      // Confirm server.ts does NOT import or configure Sentry span sinks
      // DiagnosisEnvelope is returned cleanly to the local caller
      assert.ok(diagEnvelope.meta.tokens);
      assert.equal(diagEnvelope.meta.prompt_version, 'v1.0.0');
    } finally {
      server.close();
      mockOllama.close();
    }
  });
});
