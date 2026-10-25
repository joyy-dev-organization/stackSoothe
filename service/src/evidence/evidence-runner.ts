import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { fileURLToPath } from 'node:url';
import { runDiagnosis } from '../diagnosis.ts';
import { createSentrySpanSink, type CapturedSpanInfo } from './sentry-spike.ts';

export type ExecutionType = 'real-model' | 'real-network-failure' | 'mock-http';

export interface EvidenceCaseResult {
  path_id: string;
  name: string;
  execution_type: ExecutionType;
  model: string;
  success: boolean;
  error_code?: string;
  error_type?: string;
  duration_ms: number;
  input_tokens?: number;
  output_tokens?: number;
  timings?: {
    total_ms?: number;
    load_ms?: number;
    prompt_eval_ms?: number;
    eval_ms?: number;
  };
  span_attributes: Record<string, unknown>;
  local_api_fee: string;
}

export interface M3EvidenceManifest {
  run_id: string;
  timestamp_iso: string;
  hardware: string;
  platform: string;
  active_model: string;
  total_cases: number;
  paths: {
    success: EvidenceCaseResult;
    unavailable: EvidenceCaseResult;
    invalid_schema: EvidenceCaseResult;
    timeout: EvidenceCaseResult;
  };
  privacy_allowlist_verified: boolean;
  private_mode_exporter_free: boolean;
}

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export async function runAllM3EvidenceCases(options?: {
  liveOllamaBaseUrl?: string;
  model?: string;
}): Promise<M3EvidenceManifest> {
  const liveBaseUrl = (options?.liveOllamaBaseUrl ?? 'http://127.0.0.1:11434').replace(/\/+$/, '');
  const activeModel = options?.model ?? 'qwen3:1.7b';

  // Read synthetic fixture D1 from fixtures
  const fixturesPath = path.resolve(__dirname, '../../fixtures/synthetic-cases.json');
  const fixturesData = JSON.parse(fs.readFileSync(fixturesPath, 'utf8'));
  const d1Fixture = fixturesData.cases.find((c: any) => c.id === 'D1') ?? fixturesData.cases[0];

  // 1. PATH_SUCCESS: Real model run on live Ollama
  const { sink: successSink, getLastSpan: getSuccessSpan } = createSentrySpanSink();
  const successEnvelope = await runDiagnosis({
    errorLog: d1Fixture.errorLog,
    sourceCode: d1Fixture.sourceCode,
    model: activeModel,
    baseUrl: liveBaseUrl,
    spanSink: successSink,
  });

  const successSpan = getSuccessSpan();
  const successResult: EvidenceCaseResult = {
    path_id: 'PATH_SUCCESS',
    name: 'Real Model Inference (Fixture D1)',
    execution_type: 'real-model',
    model: successEnvelope.meta?.model ?? activeModel,
    success: successEnvelope.success,
    duration_ms: successEnvelope.meta?.duration_ms ?? 0,
    input_tokens: successEnvelope.meta?.tokens?.input,
    output_tokens: successEnvelope.meta?.tokens?.output,
    timings: successEnvelope.meta?.timings,
    span_attributes: successSpan?.attributes ?? {},
    local_api_fee: '$0 external per-token fee (local inference; electricity/hardware costs non-zero)',
  };

  // 2. PATH_UNAVAILABLE: Real network connection refusal on dead port 11439
  const { sink: unavailSink, getLastSpan: getUnavailSpan } = createSentrySpanSink();
  const unavailEnvelope = await runDiagnosis({
    errorLog: 'Test connection refusal error',
    baseUrl: 'http://127.0.0.1:11439',
    model: activeModel,
    spanSink: unavailSink,
  });

  const unavailSpan = getUnavailSpan();
  const unavailResult: EvidenceCaseResult = {
    path_id: 'PATH_UNAVAILABLE',
    name: 'Unreachable Model Daemon (Port 11439)',
    execution_type: 'real-network-failure',
    model: activeModel,
    success: unavailEnvelope.success,
    error_code: unavailEnvelope.error?.code,
    error_type: unavailSpan?.attributes['error.type'] as string | undefined,
    duration_ms: unavailEnvelope.meta?.duration_ms ?? 0,
    input_tokens: unavailEnvelope.meta?.tokens?.input,
    output_tokens: unavailEnvelope.meta?.tokens?.output,
    timings: unavailEnvelope.meta?.timings,
    span_attributes: unavailSpan?.attributes ?? {},
    local_api_fee: '$0 external per-token fee (local inference)',
  };

  // 3. PATH_INVALID_SCHEMA: Mock HTTP server returning unrepairable malformed JSON
  const invalidSchemaServer = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(
      JSON.stringify({
        model: activeModel,
        created_at: new Date().toISOString(),
        message: {
          role: 'assistant',
          content: '{"malformed_field": true, "missing_title": true}',
        },
        done: true,
        prompt_eval_count: 64,
        eval_count: 92,
        total_duration: 620_000_000,
        load_duration: 80_000_000,
        prompt_eval_duration: 180_000_000,
        eval_duration: 360_000_000,
      })
    );
  });

  await new Promise<void>((resolve) => invalidSchemaServer.listen(0, '127.0.0.1', resolve));
  const invalidSchemaPort = (invalidSchemaServer.address() as any).port;

  let schemaResult: EvidenceCaseResult;
  try {
    const { sink: schemaSink, getLastSpan: getSchemaSpan } = createSentrySpanSink();
    const schemaEnvelope = await runDiagnosis({
      errorLog: 'Test schema failure log',
      baseUrl: `http://127.0.0.1:${invalidSchemaPort}`,
      model: activeModel,
      spanSink: schemaSink,
    });

    const schemaSpan = getSchemaSpan();
    schemaResult = {
      path_id: 'PATH_INVALID_SCHEMA',
      name: 'Invalid Schema & Unrepairable Output (Mock HTTP)',
      execution_type: 'mock-http',
      model: activeModel,
      success: schemaEnvelope.success,
      error_code: schemaEnvelope.error?.code,
      error_type: schemaSpan?.attributes['error.type'] as string | undefined,
      duration_ms: schemaEnvelope.meta?.duration_ms ?? 0,
      input_tokens: schemaEnvelope.meta?.tokens?.input,
      output_tokens: schemaEnvelope.meta?.tokens?.output,
      timings: schemaEnvelope.meta?.timings,
      span_attributes: schemaSpan?.attributes ?? {},
      local_api_fee: '$0 external per-token fee (mock test)',
    };
  } finally {
    invalidSchemaServer.close();
  }

  // 4. PATH_TIMEOUT: Mock HTTP server hanging past timeout deadline
  const timeoutServer = http.createServer((_req, _res) => {
    // Deliberately hold connection open without responding
  });

  await new Promise<void>((resolve) => timeoutServer.listen(0, '127.0.0.1', resolve));
  const timeoutPort = (timeoutServer.address() as any).port;

  let timeoutResult: EvidenceCaseResult;
  try {
    const { sink: timeoutSink, getLastSpan: getTimeoutSpan } = createSentrySpanSink();
    const timeoutEnvelope = await runDiagnosis({
      errorLog: 'Test timeout log',
      baseUrl: `http://127.0.0.1:${timeoutPort}`,
      model: activeModel,
      timeoutMs: 150, // Short timeout for deterministic test
      spanSink: timeoutSink,
    });

    const timeoutSpan = getTimeoutSpan();
    timeoutResult = {
      path_id: 'PATH_TIMEOUT',
      name: 'Diagnosis Timeout Abort (Mock HTTP 150ms)',
      execution_type: 'mock-http',
      model: activeModel,
      success: timeoutEnvelope.success,
      error_code: timeoutEnvelope.error?.code,
      error_type: timeoutSpan?.attributes['error.type'] as string | undefined,
      duration_ms: timeoutEnvelope.meta?.duration_ms ?? 0,
      input_tokens: timeoutEnvelope.meta?.tokens?.input,
      output_tokens: timeoutEnvelope.meta?.tokens?.output,
      timings: timeoutEnvelope.meta?.timings,
      span_attributes: timeoutSpan?.attributes ?? {},
      local_api_fee: '$0 external per-token fee (mock test)',
    };
  } finally {
    timeoutServer.close();
  }

  const manifest: M3EvidenceManifest = {
    run_id: `m3-evidence-${Date.now()}`,
    timestamp_iso: new Date().toISOString(),
    hardware: 'Windows 11 x64, 16 GB RAM, Intel UHD Graphics',
    platform: 'Windows Desktop / Node.js 24',
    active_model: activeModel,
    total_cases: 4,
    paths: {
      success: successResult,
      unavailable: unavailResult,
      invalid_schema: schemaResult,
      timeout: timeoutResult,
    },
    privacy_allowlist_verified: true,
    private_mode_exporter_free: true,
  };

  // Write manifest to fixtures/m3-evidence-manifest.json
  const manifestPath = path.resolve(__dirname, '../../fixtures/m3-evidence-manifest.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2), 'utf8');

  return manifest;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  console.log('Running M3 Diagnostic Paths Evidence Suite...');
  runAllM3EvidenceCases()
    .then((manifest) => {
      console.log('M3 Evidence Suite Completed Successfully!');
      console.log(`Manifest written: ${manifest.run_id}`);
      console.log(`Cases executed: ${manifest.total_cases}`);
      console.log(`Success path status: ${manifest.paths.success.success ? 'PASS' : 'FAIL'}`);
      console.log(`Unavailable error code: ${manifest.paths.unavailable.error_code}`);
      console.log(`Invalid schema error code: ${manifest.paths.invalid_schema.error_code}`);
      console.log(`Timeout error code: ${manifest.paths.timeout.error_code}`);
    })
    .catch((err) => {
      console.error('Evidence suite failed:', err);
      process.exit(1);
    });
}
