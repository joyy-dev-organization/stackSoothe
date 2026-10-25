import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { runDiagnosis, type SpanSink } from '../src/diagnosis.ts';

test('Defect Reproducers: Timeout Conflation and Token/Timing Loss on Schema Failure', async (t) => {
  await t.test('Defect 1: Timeout must yield OLLAMA_TIMEOUT and span errorType TIMEOUT (not OLLAMA_UNREACHABLE)', async () => {
    let capturedErrorType: string | undefined;
    const spanSink: SpanSink = {
      onError(info) {
        capturedErrorType = info.errorType;
      },
    };

    const originalFetch = globalThis.fetch;
    try {
      globalThis.fetch = async () => {
        const timeoutErr = new Error('The operation was aborted due to timeout');
        timeoutErr.name = 'TimeoutError';
        throw timeoutErr;
      };

      const envelope = await runDiagnosis({
        errorLog: 'Test error',
        baseUrl: 'http://127.0.0.1:11434',
        spanSink,
      });

      assert.equal(envelope.success, false);
      // Pre-fix code returns 'OLLAMA_UNREACHABLE' and records 'NETWORK_OR_TIMEOUT'
      // Expected fix requires 'OLLAMA_TIMEOUT' and 'TIMEOUT'
      assert.equal(
        envelope.error?.code,
        'OLLAMA_TIMEOUT',
        `Expected error code OLLAMA_TIMEOUT but received ${envelope.error?.code}`
      );
      assert.equal(
        capturedErrorType,
        'TIMEOUT',
        `Expected span errorType TIMEOUT but received ${capturedErrorType}`
      );
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  await t.test('Defect 2: Schema validation failure must preserve token counts and converted timings in SpanSink and envelope', async () => {
    let capturedSpanError: any;
    const spanSink: SpanSink = {
      onError(info) {
        capturedSpanError = info;
      },
    };

    // Spin up mock server returning invalid JSON that fails schema & repair
    const server = http.createServer((req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          model: 'qwen3:1.7b',
          created_at: new Date().toISOString(),
          message: {
            role: 'assistant',
            content: JSON.stringify({ invalid_schema_response: true }),
          },
          done: true,
          prompt_eval_count: 55,
          eval_count: 88,
          total_duration: 500_000_000, // 500 ms in nanos
          load_duration: 100_000_000,  // 100 ms in nanos
          prompt_eval_duration: 150_000_000,
          eval_duration: 250_000_000,
        })
      );
    });

    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    const address = server.address() as { port: number };
    const mockUrl = `http://127.0.0.1:${address.port}`;

    try {
      const envelope = await runDiagnosis({
        errorLog: 'Test schema failure error',
        baseUrl: mockUrl,
        spanSink,
      });

      assert.equal(envelope.success, false);
      assert.equal(envelope.error?.code, 'SCHEMA_VALIDATION_ERROR');

      // Pre-fix: SpanSink.onError drops inputTokens and outputTokens, and drops nanosecond timings
      assert.ok(capturedSpanError, 'SpanSink.onError should have been called');
      assert.equal(
        capturedSpanError.inputTokens,
        55,
        `Expected capturedSpanError.inputTokens to be 55 but got ${capturedSpanError.inputTokens}`
      );
      assert.equal(
        capturedSpanError.outputTokens,
        88,
        `Expected capturedSpanError.outputTokens to be 88 but got ${capturedSpanError.outputTokens}`
      );

      // Pre-fix: Nanosecond timings are discarded. Post-fix: converted to ms
      assert.ok(
        capturedSpanError.timings,
        'Expected capturedSpanError.timings to be populated'
      );
      assert.equal(capturedSpanError.timings?.totalMs, 500);
      assert.equal(capturedSpanError.timings?.loadMs, 100);

      // Verify envelope meta timings
      assert.ok((envelope.meta as any).timings, 'Expected envelope.meta.timings to be defined');
      assert.equal((envelope.meta as any).timings.total_ms, 500);
    } finally {
      server.close();
    }
  });
});
