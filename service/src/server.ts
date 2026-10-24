import http from 'node:http';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runDiagnosis } from './diagnosis.ts';
import { DiagnoseRequestSchema } from './schemas/diagnosis.schema.ts';

const PORT = parseInt(process.env.PORT ?? '11435', 10);
const HOST = '127.0.0.1';
const MAX_BODY_BYTES = 100 * 1024; // 100 KB limit

// Generate or retrieve bearer token
let authToken = process.env.STACKSOOTHE_TOKEN;
if (!authToken) {
  authToken = crypto.randomBytes(24).toString('hex');
  const tokenFile = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '../.stacksoothe-token'
  );
  try {
    fs.writeFileSync(tokenFile, authToken, { mode: 0o600 });
  } catch {
    // Ignore if running in read-only environment
  }
}

let isInferring = false;

function validateHost(hostHeader: string | undefined, port: number): boolean {
  if (!hostHeader) return false;
  const normalized = hostHeader.toLowerCase().trim();
  return (
    normalized === `127.0.0.1:${port}` ||
    normalized === `localhost:${port}` ||
    normalized === '127.0.0.1' ||
    normalized === 'localhost'
  );
}

export function createServer(customToken?: string, customPort?: number, ollamaBaseUrl?: string) {
  const token = customToken ?? authToken;
  const port = customPort ?? PORT;
  let diagnosisRequestCount = 0;

  const server = http.createServer((req, res) => {
    // 1. Enforce exact Host header
    if (!validateHost(req.headers.host, port)) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'INVALID_HOST', message: 'Rejected host header' }));
      return;
    }

    // 2. Reject browser Origin headers to prevent cross-origin abuse
    if (req.headers.origin) {
      res.writeHead(403, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'FORBIDDEN_ORIGIN', message: 'Browser origins rejected' }));
      return;
    }

    // 3. Health check (no auth needed for readiness probe)
    if (req.method === 'GET' && req.url === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          status: 'ok',
          service: 'stacksoothe-service',
          busy: isInferring,
          diagnosis_request_count: diagnosisRequestCount,
        })
      );
      return;
    }

    // 4. Enforce Bearer token auth for all other endpoints
    const authHeader = req.headers.authorization;
    if (!authHeader || authHeader !== `Bearer ${token}`) {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'UNAUTHORIZED', message: 'Invalid or missing bearer token' }));
      return;
    }

    // 5. Diagnosis route
    if (req.method === 'POST' && req.url === '/api/diagnose') {
      // Concurrency lock
      if (isInferring) {
        res.writeHead(429, { 'Content-Type': 'application/json' });
        res.end(
          JSON.stringify({
            error: 'BUSY',
            message: 'Another diagnosis request is currently in progress.',
          })
        );
        return;
      }

      let body = '';
      let bytesReceived = 0;

      req.on('data', (chunk: Buffer) => {
        bytesReceived += chunk.length;
        if (bytesReceived > MAX_BODY_BYTES) {
          req.destroy(new Error('REQUEST_BODY_TOO_LARGE'));
          if (!res.headersSent) {
            res.writeHead(413, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'PAYLOAD_TOO_LARGE', message: 'Body exceeded 100 KB' }));
          }
          return;
        }
        body += chunk.toString('utf8');
      });

      req.on('end', async () => {
        if (bytesReceived > MAX_BODY_BYTES) return;

        let parsedJson: unknown;
        try {
          parsedJson = JSON.parse(body);
        } catch {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'INVALID_JSON', message: 'Malformed JSON payload' }));
          return;
        }

        const inputValidation = DiagnoseRequestSchema.safeParse(parsedJson);
        if (!inputValidation.success) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(
            JSON.stringify({
              error: 'VALIDATION_ERROR',
              message: 'Invalid request parameters',
              details: inputValidation.error.issues,
            })
          );
          return;
        }

        isInferring = true;
        diagnosisRequestCount++;
        try {
          const envelope = await runDiagnosis({
            errorLog: inputValidation.data.errorLog,
            sourceCode: inputValidation.data.sourceCode,
            model: inputValidation.data.model,
            baseUrl: ollamaBaseUrl,
          });

          res.writeHead(envelope.success ? 200 : 502, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(envelope));
        } catch (error) {
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(
            JSON.stringify({
              error: 'INTERNAL_ERROR',
              message: error instanceof Error ? error.message : String(error),
            })
          );
        } finally {
          isInferring = false;
        }
      });

      req.on('error', () => {
        isInferring = false;
      });

      return;
    }

    // 404 for unknown routes
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'NOT_FOUND', message: 'Route not found' }));
  });

  return { server, token, port: PORT, host: HOST };
}

// Start if executed directly
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { server, port, host, token } = createServer();
  server.listen(port, host, () => {
    console.log(`StackSoothe diagnosis service running on http://${host}:${port}`);
    console.log(`Bearer token configured: ${token.slice(0, 6)}...${token.slice(-4)}`);
  });
}
