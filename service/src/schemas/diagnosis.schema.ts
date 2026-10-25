import { z } from 'zod';

export const SeverityEnum = z.enum(['low', 'medium', 'high']);
export type Severity = z.infer<typeof SeverityEnum>;

export const ConfidenceEnum = z.enum(['Low', 'Medium', 'High']);
export type Confidence = z.infer<typeof ConfidenceEnum>;

export const DiagnosisSchema = z.object({
  title: z.string().trim().min(3).max(120),
  severity: SeverityEnum,
  summary: z.string().trim().min(10).max(1000),
  likely_cause: z.string().trim().min(10).max(2000),
  confidence: ConfidenceEnum,
  steps: z
    .array(z.string().trim().min(5).max(300))
    .min(1)
    .max(7),
  verification: z
    .array(z.string().trim().min(5).max(300))
    .min(1)
    .max(5),
  code_example: z.string().max(2000).default(''),
});

export type DiagnosisData = z.infer<typeof DiagnosisSchema>;

export const DiagnoseRequestSchema = z.object({
  errorLog: z.string().trim().min(1, 'Error log is required').max(50000),
  sourceCode: z.string().max(50000).default(''),
  model: z.string().trim().min(1).default('qwen3:1.7b'),
});

export type DiagnoseRequest = z.infer<typeof DiagnoseRequestSchema>;
