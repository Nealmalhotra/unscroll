// Shared test helpers: boot the app on an ephemeral port with a temp DATA_FILE.

import { mkdtempSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createApp } from '../src/server.js';

const SERVER_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

export function makeTempDir() {
  return mkdtempSync(join(SERVER_ROOT, '.tmp-test-'));
}

export async function startServer(options = {}) {
  const dir = makeTempDir();
  const logs = [];
  const app = createApp({
    dataFile: join(dir, 'db.json'),
    adminToken: 'test-admin-token',
    rateLimitPerMinute: 10_000,
    log: (entry) => logs.push(entry),
    ...options,
  });
  await new Promise((resolve) => app.server.listen(0, '127.0.0.1', resolve));
  const baseUrl = `http://127.0.0.1:${app.server.address().port}`;

  async function request(method, path, { body, token, headers = {}, raw } = {}) {
    const finalHeaders = { ...headers };
    if (token) finalHeaders.authorization = `Bearer ${token}`;
    let payload = raw;
    if (body !== undefined) {
      payload = JSON.stringify(body);
      finalHeaders['content-type'] = finalHeaders['content-type'] ?? 'application/json';
    }
    const res = await fetch(`${baseUrl}${path}`, { method, headers: finalHeaders, body: payload });
    const text = await res.text();
    return { status: res.status, headers: res.headers, json: JSON.parse(text) };
  }

  async function createUser(handle) {
    const res = await request('POST', '/v1/users', { body: { handle } });
    if (res.status !== 201) throw new Error(`createUser failed: ${JSON.stringify(res.json)}`);
    return res.json.data;
  }

  async function close() {
    await new Promise((resolve) => app.server.close(resolve));
    rmSync(dir, { recursive: true, force: true });
  }

  return { app, baseUrl, dir, logs, request, createUser, close };
}
