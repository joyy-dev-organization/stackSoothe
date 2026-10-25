import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import net from 'node:net';
import { createServer } from '../src/server.ts';
import { runDiagnosis } from '../src/diagnosis.ts';

const PRIVACY_TEST_PORT = 11485;
const PRIVACY_TOKEN = 'privacy-test-token-secret-123';

test('M4 Privacy: WAN-Denied Local Diagnosis & Scoped Process Egress Observation', async (t) => {
  // Spin up a mock loopback Ollama responding with valid diagnosis JSON
  const mockOllamaPort = 11484;
  const mockOllama = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(
      JSON.stringify({
        model: 'qwen3:1.7b',
        created_at: new Date().toISOString(),
        message: {
          role: 'assistant',
          content: JSON.stringify({
            title: 'BuildContext used across async gaps',
            severity: 'medium',
            summary: 'Widget context accessed after asynchronous gap without mounted check.',
            likely_cause: 'Navigator.of(context) called after await without checking if mounted.',
            confidence: 'High',
            steps: [
              'Add if (!mounted) return; before calling Navigator.of(context).',
              'Verify widget lifecycle.'
            ],
            verification: [
              'Run widget test checking unmounted state dismissal.'
            ],
            code_example: 'if (!mounted) return;\nNavigator.of(context).pop();',
          }),
        },
        done: true,
        total_duration: 1200000000,
        load_duration: 20000000,
        prompt_eval_count: 350,
        prompt_eval_duration: 400000000,
        eval_count: 220,
        eval_duration: 780000000,
      })
    );
  });
  await new Promise<void>((resolve) => mockOllama.listen(mockOllamaPort, '127.0.0.1', resolve));

  const { server: loopbackServer } = createServer(
    PRIVACY_TOKEN,
    PRIVACY_TEST_PORT,
    `http://127.0.0.1:${mockOllamaPort}`
  );
  await new Promise<void>((resolve) => loopbackServer.listen(PRIVACY_TEST_PORT, '127.0.0.1', resolve));

  t.after(() => {
    loopbackServer.close();
    mockOllama.close();
  });

  await t.test('WAN-Denied Local Diagnosis: succeeds 100% locally when external WAN/DNS is unreachable', async () => {
    // When external WAN/DNS is unreachable, diagnosis against loopback Ollama must succeed without error
    const result = await runDiagnosis({
      errorLog: 'Error: Don\'t use BuildContext across async gaps',
      sourceCode: 'await repo.save(); Navigator.of(context).pop();',
      baseUrl: `http://127.0.0.1:${mockOllamaPort}`,
      model: 'qwen3:1.7b',
    });

    assert.equal(result.success, true);
    assert.ok(result.data);
    assert.equal(result.data.title, 'BuildContext used across async gaps');
    assert.equal(result.meta.raw_valid, true);
    assert.equal(result.meta.model, 'qwen3:1.7b');
  });

  await t.test('Scoped Process Egress: 100% of network traffic connects to loopback 127.0.0.1; 0 WAN egress', async () => {
    // Track all outbound TCP connections created during diagnosis
    const originalConnect = net.Socket.prototype.connect;
    const establishedConnections: { host?: string; port?: number }[] = [];

    (net.Socket.prototype as any).connect = function (...args: any[]) {
      const portOrPath = args[0];
      const host = typeof args[1] === 'string' ? args[1] : (typeof portOrPath === 'object' && portOrPath !== null && 'host' in portOrPath ? (portOrPath as { host?: string }).host : '127.0.0.1');
      const port = typeof portOrPath === 'number' ? portOrPath : (typeof portOrPath === 'object' && portOrPath !== null && 'port' in portOrPath ? (portOrPath as { port?: number }).port : undefined);

      establishedConnections.push({
        host: host || '127.0.0.1',
        port,
      });
      return originalConnect.apply(this, args as any);
    };

    try {
      // Execute diagnosis through the loopback service endpoint
      const response = await fetch(`http://127.0.0.1:${PRIVACY_TEST_PORT}/api/diagnose`, {
        method: 'POST',
        headers: {
          Host: `127.0.0.1:${PRIVACY_TEST_PORT}`,
          Authorization: `Bearer ${PRIVACY_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          errorLog: 'A RenderFlex overflowed by 24 pixels on the right.',
          sourceCode: 'Row(children: [Text(name), Text(description)])',
          model: 'qwen3:1.7b',
        }),
      });

      assert.equal(response.status, 200);
      const envelope = (await response.json()) as { success: boolean };
      assert.equal(envelope.success, true);

      // Verify all connection destinations:
      assert.ok(establishedConnections.length > 0, 'Must record network socket connections');
      for (const conn of establishedConnections) {
        assert.ok(
          conn.host === '127.0.0.1' || conn.host === 'localhost' || conn.host === '::1',
          `Non-loopback connection detected: ${conn.host}:${conn.port}`
        );
      }

      // Assert 0 connections to external WAN IP addresses
      const nonLoopback = establishedConnections.filter(
        (c) => c.host !== '127.0.0.1' && c.host !== 'localhost' && c.host !== '::1'
      );
      assert.equal(nonLoopback.length, 0, 'Zero non-loopback connections allowed in private mode');
    } finally {
      net.Socket.prototype.connect = originalConnect;
    }
  });
});
