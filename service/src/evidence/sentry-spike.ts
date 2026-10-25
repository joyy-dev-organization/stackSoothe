import * as Sentry from '@sentry/node';
import { runDiagnosis, type SpanSink, type SpanTimings } from '../diagnosis.ts';
import type { DiagnosisEnvelope } from '../types/diagnosis.ts';

export interface CapturedSpanInfo {
  op: string;
  name: string;
  attributes: Record<string, unknown>;
  status?: string;
}

export interface SentrySpikeResult {
  envelope: DiagnosisEnvelope;
  capturedSpan?: CapturedSpanInfo;
}

/**
 * Creates an instrumented SpanSink that hooks into Sentry manual GenAI tracing.
 * Enforces strict privacy: zero prompt, code, or model output text is attached.
 */
export function createSentrySpanSink(): {
  sink: SpanSink;
  getLastSpan: () => CapturedSpanInfo | undefined;
  getSentrySpan: () => any;
} {
  let recordedSpan: CapturedSpanInfo | undefined;
  let activeSentrySpan: any;

  const sink: SpanSink = {
    onStart({ model, provider }) {
      recordedSpan = {
        op: 'gen_ai.chat',
        name: `chat ${model}`,
        attributes: {
          'gen_ai.operation.name': 'chat',
          'gen_ai.provider.name': provider,
          'gen_ai.request.model': model,
        },
      };

      if (Sentry.isInitialized()) {
        activeSentrySpan = Sentry.startInactiveSpan({
          op: 'gen_ai.chat',
          name: `chat ${model}`,
        });
        activeSentrySpan.setAttribute('gen_ai.operation.name', 'chat');
        activeSentrySpan.setAttribute('gen_ai.provider.name', provider);
        activeSentrySpan.setAttribute('gen_ai.request.model', model);
      }
    },
    onSuccess({ model, inputTokens, outputTokens, durationMs, timings }) {
      if (recordedSpan) {
        recordedSpan.attributes['gen_ai.response.model'] = model;
        recordedSpan.attributes['gen_ai.duration_ms'] = durationMs;
        if (inputTokens !== undefined) {
          recordedSpan.attributes['gen_ai.usage.input_tokens'] = inputTokens;
        }
        if (outputTokens !== undefined) {
          recordedSpan.attributes['gen_ai.usage.output_tokens'] = outputTokens;
        }
        if (timings) {
          if (timings.totalMs !== undefined) {
            recordedSpan.attributes['ollama.timing.total_ms'] = timings.totalMs;
          }
          if (timings.loadMs !== undefined) {
            recordedSpan.attributes['ollama.timing.load_ms'] = timings.loadMs;
          }
          if (timings.promptEvalMs !== undefined) {
            recordedSpan.attributes['ollama.timing.prompt_eval_ms'] = timings.promptEvalMs;
          }
          if (timings.evalMs !== undefined) {
            recordedSpan.attributes['ollama.timing.eval_ms'] = timings.evalMs;
          }
        }
        recordedSpan.status = 'ok';
      }

      if (activeSentrySpan) {
        activeSentrySpan.setAttribute('gen_ai.response.model', model);
        activeSentrySpan.setAttribute('gen_ai.duration_ms', durationMs);
        if (inputTokens !== undefined) {
          activeSentrySpan.setAttribute('gen_ai.usage.input_tokens', inputTokens);
        }
        if (outputTokens !== undefined) {
          activeSentrySpan.setAttribute('gen_ai.usage.output_tokens', outputTokens);
        }
        if (timings) {
          if (timings.totalMs !== undefined) {
            activeSentrySpan.setAttribute('ollama.timing.total_ms', timings.totalMs);
          }
          if (timings.loadMs !== undefined) {
            activeSentrySpan.setAttribute('ollama.timing.load_ms', timings.loadMs);
          }
          if (timings.promptEvalMs !== undefined) {
            activeSentrySpan.setAttribute('ollama.timing.prompt_eval_ms', timings.promptEvalMs);
          }
          if (timings.evalMs !== undefined) {
            activeSentrySpan.setAttribute('ollama.timing.eval_ms', timings.evalMs);
          }
        }
        activeSentrySpan.setStatus({ code: 1, message: 'ok' });
        activeSentrySpan.end();
      }
    },
    onError({ model, errorType, durationMs, inputTokens, outputTokens, timings }) {
      if (recordedSpan) {
        if (model) {
          recordedSpan.attributes['gen_ai.response.model'] = model;
        }
        recordedSpan.attributes['error.type'] = errorType;
        recordedSpan.attributes['gen_ai.duration_ms'] = durationMs;
        if (inputTokens !== undefined) {
          recordedSpan.attributes['gen_ai.usage.input_tokens'] = inputTokens;
        }
        if (outputTokens !== undefined) {
          recordedSpan.attributes['gen_ai.usage.output_tokens'] = outputTokens;
        }
        if (timings) {
          if (timings.totalMs !== undefined) {
            recordedSpan.attributes['ollama.timing.total_ms'] = timings.totalMs;
          }
          if (timings.loadMs !== undefined) {
            recordedSpan.attributes['ollama.timing.load_ms'] = timings.loadMs;
          }
          if (timings.promptEvalMs !== undefined) {
            recordedSpan.attributes['ollama.timing.prompt_eval_ms'] = timings.promptEvalMs;
          }
          if (timings.evalMs !== undefined) {
            recordedSpan.attributes['ollama.timing.eval_ms'] = timings.evalMs;
          }
        }
        recordedSpan.status = errorType;
      }

      if (activeSentrySpan) {
        if (model) {
          activeSentrySpan.setAttribute('gen_ai.response.model', model);
        }
        activeSentrySpan.setAttribute('error.type', errorType);
        activeSentrySpan.setAttribute('gen_ai.duration_ms', durationMs);
        if (inputTokens !== undefined) {
          activeSentrySpan.setAttribute('gen_ai.usage.input_tokens', inputTokens);
        }
        if (outputTokens !== undefined) {
          activeSentrySpan.setAttribute('gen_ai.usage.output_tokens', outputTokens);
        }
        if (timings) {
          if (timings.totalMs !== undefined) {
            activeSentrySpan.setAttribute('ollama.timing.total_ms', timings.totalMs);
          }
          if (timings.loadMs !== undefined) {
            activeSentrySpan.setAttribute('ollama.timing.load_ms', timings.loadMs);
          }
          if (timings.promptEvalMs !== undefined) {
            activeSentrySpan.setAttribute('ollama.timing.prompt_eval_ms', timings.promptEvalMs);
          }
          if (timings.evalMs !== undefined) {
            activeSentrySpan.setAttribute('ollama.timing.eval_ms', timings.evalMs);
          }
        }
        activeSentrySpan.setStatus({ code: 2, message: errorType });
        activeSentrySpan.end();
      }
    },
  };

  return {
    sink,
    getLastSpan: () => recordedSpan,
    getSentrySpan: () => activeSentrySpan,
  };
}

/**
 * Executes a synthetic diagnosis run with Sentry manual instrumentation.
 * Intended for offline evidence generation using checked-in fixtures only.
 */
export async function runSyntheticSentrySpike(fixture: {
  errorLog: string;
  sourceCode?: string;
  model?: string;
  baseUrl?: string;
  timeoutMs?: number;
}): Promise<SentrySpikeResult> {
  // Initialize Sentry with default integrations disabled to avoid auto-capturing breadcrumbs/requests
  if (!Sentry.isInitialized()) {
    Sentry.init({
      dsn:
        process.env.SENTRY_DSN ||
        'https://0123456789abcdef0123456789abcdef@example.ingest.sentry.io/1234567',
      defaultIntegrations: false,
      tracesSampleRate: 1.0,
    });
  }

  const { sink, getLastSpan } = createSentrySpanSink();

  const envelope = await runDiagnosis({
    errorLog: fixture.errorLog,
    sourceCode: fixture.sourceCode,
    model: fixture.model,
    baseUrl: fixture.baseUrl,
    timeoutMs: fixture.timeoutMs,
    spanSink: sink,
  });

  return {
    envelope,
    capturedSpan: getLastSpan(),
  };
}
