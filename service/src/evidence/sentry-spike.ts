import * as Sentry from '@sentry/node';
import { runDiagnosis, type SpanSink } from '../diagnosis.ts';
import type { DiagnosisEnvelope } from '../types/diagnosis.ts';

export interface SentrySpikeResult {
  envelope: DiagnosisEnvelope;
  capturedSpan?: {
    op: string;
    name: string;
    attributes: Record<string, unknown>;
  };
}

/**
 * Creates an instrumented SpanSink that hooks into Sentry manual GenAI tracing.
 * Enforces strict privacy: zero prompt, code, or model output text is attached.
 */
export function createSentrySpanSink(): {
  sink: SpanSink;
  getLastSpan: () => { op: string; name: string; attributes: Record<string, unknown> } | undefined;
} {
  let recordedSpan: { op: string; name: string; attributes: Record<string, unknown> } | undefined;

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
    },
    onSuccess({ model, inputTokens, outputTokens, durationMs }) {
      if (recordedSpan) {
        recordedSpan.attributes['gen_ai.response.model'] = model;
        recordedSpan.attributes['gen_ai.duration_ms'] = durationMs;
        if (inputTokens !== undefined) {
          recordedSpan.attributes['gen_ai.usage.input_tokens'] = inputTokens;
        }
        if (outputTokens !== undefined) {
          recordedSpan.attributes['gen_ai.usage.output_tokens'] = outputTokens;
        }
      }
    },
    onError({ errorType, durationMs }) {
      if (recordedSpan) {
        recordedSpan.attributes['error.type'] = errorType;
        recordedSpan.attributes['gen_ai.duration_ms'] = durationMs;
      }
    },
  };

  return { sink, getLastSpan: () => recordedSpan };
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
}): Promise<SentrySpikeResult> {
  // Initialize Sentry with default integrations disabled to avoid auto-capturing breadcrumbs/requests
  if (!Sentry.isInitialized()) {
    Sentry.init({
      dsn: process.env.SENTRY_DSN || 'https://synthetic@example.ingest.sentry.io/1234567',
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
    spanSink: sink,
  });

  return {
    envelope,
    capturedSpan: getLastSpan(),
  };
}
