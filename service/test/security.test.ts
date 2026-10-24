import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { createServer } from '../src/server.ts';

const TEST_PORT = 11499;
const TEST_TOKEN = 'test-secret-token-12345';

function sendRequest(options: {
  method?: string;
  path?: string;
  headers?: Record<string, string>;
  body?: string;
}): Promise<{ statusCode: number; body: string }> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: TEST_PORT,
        path: options.path ?? '/health',
        method: options.method ?? 'GET',
        headers: {
          Host: `127.0.0.1:${TEST_PORT}`,
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

test('Security & Boundary Enforcement', async (t) => {
  const { server } = createServer(TEST_TOKEN, TEST_PORT);
  await new Promise<void>((resolve) => server.listen(TEST_PORT, '127.0.0.1', resolve));

  t.after(() => {
    server.close();
  });

  await t.test('enforces exact Host header (rejects suffix lookalikes)', async () => {
    // Malicious host lookalike
    const res = await sendRequest({
      headers: { Host: 'localhost.attacker.com' },
    });
    assert.equal(res.statusCode, 400);
    assert.match(res.body, /INVALID_HOST/);
  });

  await t.test('rejects browser Origin headers (CSRF defense)', async () => {
    const res = await sendRequest({
      headers: { Origin: 'http://evil.com' },
    });
    assert.equal(res.statusCode, 403);
    assert.match(res.body, /FORBIDDEN_ORIGIN/);
  });

  await t.test('health endpoint succeeds without auth', async () => {
    const res = await sendRequest({ path: '/health' });
    assert.equal(res.statusCode, 200);
    assert.match(res.body, /"status":"ok"/);
  });

  await t.test('protected endpoints require valid Bearer token', async () => {
    // Missing token
    const resMissing = await sendRequest({
      method: 'POST',
      path: '/api/diagnose',
      body: JSON.stringify({ errorLog: 'Test log' }),
    });
    assert.equal(resMissing.statusCode, 401);

    // Invalid token
    const resInvalid = await sendRequest({
      method: 'POST',
      path: '/api/diagnose',
      headers: { Authorization: 'Bearer wrong-token' },
      body: JSON.stringify({ errorLog: 'Test log' }),
    });
    assert.equal(resInvalid.statusCode, 401);
  });

  await t.test('enforces 100 KB payload limit and terminates stream', async () => {
    const oversizedBody = JSON.stringify({
      errorLog: 'A'.repeat(120 * 1024), // 120 KB
    });

    const res = await sendRequest({
      method: 'POST',
      path: '/api/diagnose',
      headers: {
        Authorization: `Bearer ${TEST_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: oversizedBody,
    });

    // Destroying the socket on overflow causes statusCode 413 or connection reset (0)
    assert.ok(res.statusCode === 413 || res.statusCode === 0);
  });
});
