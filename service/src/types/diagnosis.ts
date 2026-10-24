import type { DiagnosisData } from '../schemas/diagnosis.schema.js';

export interface DiagnosisEnvelope {
  success: boolean;
  data?: DiagnosisData;
  error?: {
    code: string;
    message: string;
    details?: unknown;
  };
  meta: {
    model: string;
    prompt_version: string;
    raw_valid: boolean;
    repaired: boolean;
    duration_ms: number;
    tokens?: {
      input?: number;
      output?: number;
    };
  };
}

export interface OllamaChatResponse {
  model: string;
  created_at: string;
  message: {
    role: string;
    content: string;
  };
  done: boolean;
  total_duration?: number;
  load_duration?: number;
  prompt_eval_count?: number;
  prompt_eval_duration?: number;
  eval_count?: number;
  eval_duration?: number;
}
