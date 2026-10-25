import test from 'node:test';
import assert from 'node:assert/strict';
import * as Sentry from '@sentry/node';
import { createSentrySpanSink } from '../src/evidence/sentry-spike.ts';

test('Sentry Synthetic Evidence Spike: Span Structure & Privacy Guarantees', async (t) => {
  await t.test('creates documented GenAI chat span with allowlisted metadata only', () => {
    const { sink, getLastSpan } = createSentrySpanSink();

    const modelTag = 'qwen2.5-coder:3b';
    sink.onStart?.({ model: modelTag, provider: 'ollama' });

    let span = getLastSpan();
    assert.ok(span);
    assert.equal(span.op, 'gen_ai.chat');
    assert.equal(span.name, 'chat qwen2.5-coder:3b');
    assert.equal(span.attributes['gen_ai.operation.name'], 'chat');
    assert.equal(span.attributes['gen_ai.provider.name'], 'ollama');
    assert.equal(span.attributes['gen_ai.request.model'], modelTag);

    // Complete span with token and timing metadata
    sink.onSuccess?.({
      model: modelTag,
      inputTokens: 142,
      outputTokens: 88,
      durationMs: 1250,
      timings: {
        totalMs: 1200,
        loadMs: 150,
        promptEvalMs: 300,
        evalMs: 750,
      },
    });

    span = getLastSpan();
    assert.ok(span);
    assert.equal(span.attributes['gen_ai.response.model'], modelTag);
    assert.equal(span.attributes['gen_ai.usage.input_tokens'], 142);
    assert.equal(span.attributes['gen_ai.usage.output_tokens'], 88);
    assert.equal(span.attributes['gen_ai.duration_ms'], 1250);
    assert.equal(span.attributes['ollama.timing.total_ms'], 1200);
    assert.equal(span.attributes['ollama.timing.load_ms'], 150);
    assert.equal(span.attributes['ollama.timing.prompt_eval_ms'], 300);
    assert.equal(span.attributes['ollama.timing.eval_ms'], 750);
    assert.equal(span.status, 'ok');
  });

  await t.test('payload inspection: strictly forbids prompt, code, or output text in span attributes', () => {
    const { sink, getLastSpan } = createSentrySpanSink();

    sink.onStart?.({ model: 'qwen2.5-coder:3b', provider: 'ollama' });
    sink.onSuccess?.({
      model: 'qwen2.5-coder:3b',
      inputTokens: 200,
      outputTokens: 150,
      durationMs: 980,
      timings: {
        totalMs: 950,
        loadMs: 100,
      },
    });

    const span = getLastSpan();
    assert.ok(span);

    // Verify all attribute keys are within strictly safe allowlist
    const ALLOWLISTED_ATTRS = new Set([
      'gen_ai.operation.name',
      'gen_ai.provider.name',
      'gen_ai.request.model',
      'gen_ai.response.model',
      'gen_ai.duration_ms',
      'gen_ai.usage.input_tokens',
      'gen_ai.usage.output_tokens',
      'ollama.timing.total_ms',
      'ollama.timing.load_ms',
      'ollama.timing.prompt_eval_ms',
      'ollama.timing.eval_ms',
      'error.type',
    ]);

    for (const key of Object.keys(span.attributes)) {
      assert.ok(
        ALLOWLISTED_ATTRS.has(key),
        `Prohibited span attribute key detected: "${key}"`
      );
    }

    // Inspect values to guarantee no code/prompt text leaked into attribute values
    const serialized = JSON.stringify(span.attributes).toLowerCase();
    assert.equal(serialized.includes('errorlog'), false);
    assert.equal(serialized.includes('sourcecode'), false);
    assert.equal(serialized.includes('navigator.of'), false);
    assert.equal(serialized.includes('buildcontext'), false);
    assert.equal(serialized.includes('likely_cause'), false);
  });

  await t.test('error span captures low-cardinality error.type, tokens, and duration', () => {
    const { sink, getLastSpan } = createSentrySpanSink();

    sink.onStart?.({ model: 'qwen2.5-coder:3b', provider: 'ollama' });
    sink.onError?.({
      model: 'qwen2.5-coder:3b',
      errorType: 'HTTP_502',
      durationMs: 310,
    });

    const span = getLastSpan();
    assert.ok(span);
    assert.equal(span.attributes['error.type'], 'HTTP_502');
    assert.equal(span.attributes['gen_ai.duration_ms'], 310);
    assert.equal('raw_error' in span.attributes, false);
    assert.equal(span.status, 'HTTP_502');
  });
});
