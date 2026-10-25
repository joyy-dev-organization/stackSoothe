import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { createServer } from '../src/server.ts';
import { runDiagnosis, isLoopbackHost } from '../src/diagnosis.ts';

const M4_TEST_PORT = 11498;
const M4_TEST_TOKEN = 'test-token-m4-hardening-secret';

function makeRequest(options: {
  port?: number;
  method?: string;
  path?: string;
  headers?: Record<string, string>;
  body?: string;
}): Promise<{ statusCode: number; body: string }> {
  const port = options.port ?? M4_TEST_PORT;
  return new Promise((resolve) => {
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port,
        path: options.path ?? '/api/diagnose',
        method: options.method ?? 'POST',
        headers: {
          Host: `127.0.0.1:${port}`,
          Authorization: `Bearer ${M4_TEST_TOKEN}`,
          'Content-Type': 'application/json',
          ...options.headers,
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => resolve({ statusCode: res.statusCode ?? 0, body: data }));
      }
    );
    req.on('error', (err) => resolve({ statusCode: 0, body: err.message }));
    if (options.body) req.write(options.body);
    req.end();
  });
}

test('M4 Hardening: Loopback URL Enforcement, Concurrency Rejection & Disconnect Handling', async (t) => {
  const { server } = createServer(M4_TEST_TOKEN, M4_TEST_PORT);
  await new Promise<void>((resolve) => server.listen(M4_TEST_PORT, '127.0.0.1', resolve));

  t.after(() => {
    server.close();
  });

  await t.test('isLoopbackHost strictly accepts only 127.0.0.1, localhost, and ::1', () => {
    assert.equal(isLoopbackHost('http://127.0.0.1:11434'), true);
    assert.equal(isLoopbackHost('http://localhost:11434'), true);
    assert.equal(isLoopbackHost('http://[::1]:11434'), true);

    // Reject WAN / remote / lookalike domains
    assert.equal(isLoopbackHost('https://api.external.com'), false);
    assert.equal(isLoopbackHost('http://192.168.1.10:11434'), false);
    assert.equal(isLoopbackHost('http://localhost.attacker.com'), false);
    assert.equal(isLoopbackHost('http://10.0.0.1:11434'), false);
    assert.equal(isLoopbackHost('not-a-valid-url'), false);
  });

  await t.test('runDiagnosis rejects non-loopback Ollama baseUrl before making requests', async () => {
    const result = await runDiagnosis({
      errorLog: 'Error: RenderFlex overflowed',
      baseUrl: 'http://evil.remote-ai.com:11434',
    });

    assert.equal(result.success, false);
    assert.equal(result.error?.code, 'NON_LOOPBACK_URL_REJECTED');
    assert.match(result.error?.message ?? '', /Private mode requires a loopback Ollama endpoint/);
  });

  await t.test('Single-concurrency lock returns HTTP 429 BUSY (immediate reject, no queue)', async () => {
    // Spin up a mock slow Ollama backend that takes 1000ms
    const mockOllamaPort = 11488;
    const mockOllama = http.createServer((req, res) => {
      setTimeout(() => {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(
          JSON.stringify({
            message: {
              content: JSON.stringify({
                title: 'Test Diagnosis',
                severity: 'low',
                summary: 'Valid summary text for test',
                likely_cause: 'Valid cause description',
                confidence: 'High',
                steps: ['Step 1'],
                verification: ['Verify 1'],
                code_example: '',
              }),
            },
          })
        );
      }, 500);
    });
    await new Promise<void>((resolve) => mockOllama.listen(mockOllamaPort, '127.0.0.1', resolve));

    const slowServerPort = 11489;
    const { server: slowServer } = createServer(
      M4_TEST_TOKEN,
      slowServerPort,
      `http://127.0.0.1:${mockOllamaPort}`
    );
    await new Promise<void>((resolve) => slowServer.listen(slowServerPort, '127.0.0.1', resolve));

    try {
      // Launch first request in-flight
      const req1Promise = makeRequest({
        port: slowServerPort,
        body: JSON.stringify({ errorLog: 'Error 1' }),
      });

      // Brief delay to ensure req1 is actively in-flight
      await new Promise((r) => setTimeout(r, 50));

      // Second concurrent request must be immediately rejected with HTTP 429 BUSY
      const req2Res = await makeRequest({
        port: slowServerPort,
        body: JSON.stringify({ errorLog: 'Error 2' }),
      });

      assert.equal(req2Res.statusCode, 429);
      assert.match(req2Res.body, /BUSY/);
      assert.match(req2Res.body, /single-concurrency without queuing/);

      // req1 completes successfully
      const req1Res = await req1Promise;
      assert.equal(req1Res.statusCode, 200);
    } finally {
      slowServer.close();
      mockOllama.close();
    }
  });

  await t.test('Client disconnect aborts in-flight diagnosis and resets busy state', async () => {
    const mockOllamaPort = 11486;
    let ollamaRequestReceived = false;

    const mockOllama = http.createServer((req, res) => {
      ollamaRequestReceived = true;
      // Intentionally do not respond immediately
      setTimeout(() => {
        if (!res.writableEnded) {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end('{}');
        }
      }, 1000);
    });
    await new Promise<void>((resolve) => mockOllama.listen(mockOllamaPort, '127.0.0.1', resolve));

    const abortServerPort = 11487;
    const { server: abortServer } = createServer(
      M4_TEST_TOKEN,
      abortServerPort,
      `http://127.0.0.1:${mockOllamaPort}`
    );
    await new Promise<void>((resolve) => abortServer.listen(abortServerPort, '127.0.0.1', resolve));

    try {
      // Connect and send request, then abruptly destroy the client socket
      const clientReq = http.request({
        hostname: '127.0.0.1',
        port: abortServerPort,
        path: '/api/diagnose',
        method: 'POST',
        headers: {
          Host: `127.0.0.1:${abortServerPort}`,
          Authorization: `Bearer ${M4_TEST_TOKEN}`,
          'Content-Type': 'application/json',
        },
      });

      clientReq.on('error', () => {});
      clientReq.write(JSON.stringify({ errorLog: 'Test abort' }));
      // Destroy socket while request is processing
      await new Promise((r) => setTimeout(r, 60));
      clientReq.destroy();

      // Wait a moment for server 'close' event to execute
      await new Promise((r) => setTimeout(r, 100));

      // Probe health check: busy must be false, proving concurrency lock was released!
      const healthRes = await makeRequest({
        port: abortServerPort,
        path: '/health',
        method: 'GET',
      });
      assert.equal(healthRes.statusCode, 200);
      assert.match(healthRes.body, /"busy":false/);
    } finally {
      abortServer.close();
      mockOllama.close();
    }
  });
});
