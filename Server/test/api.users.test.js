import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createApp, resolveConfig } from '../src/server.js';
import { matchRoute } from '../src/routes.js';
import { startServer } from './helpers.js';

const assertEnvelope = (json) => {
  assert.deepEqual(Object.keys(json).sort(), ['data', 'error', 'success']);
  if (json.success) assert.equal(json.error, null);
  else {
    assert.equal(json.data, null);
    assert.equal(typeof json.error, 'string');
  }
};

test('users API', async (t) => {
  const srv = await startServer();
  t.after(() => srv.close());

  await t.test('healthz', async () => {
    const res = await srv.request('GET', '/healthz');
    assert.equal(res.status, 200);
    assert.deepEqual(res.json, { success: true, data: { ok: true }, error: null });
    assert.match(res.headers.get('content-type'), /application\/json/);
  });

  await t.test('signup returns id, handle and a 64-hex token; only the hash is stored', async () => {
    const res = await srv.request('POST', '/v1/users', { body: { handle: 'Neal_M' } });
    assert.equal(res.status, 201);
    assertEnvelope(res.json);
    const { id, handle, token } = res.json.data;
    assert.deepEqual(Object.keys(res.json.data).sort(), ['handle', 'id', 'token']);
    assert.equal(handle, 'Neal_M');
    assert.match(token, /^[0-9a-f]{64}$/);
    const disk = readFileSync(join(srv.dir, 'db.json'), 'utf8');
    assert.equal(disk.includes(token), false);
    assert.equal(JSON.parse(disk).users[id].tokenHash.length, 64);
  });

  await t.test('handles are unique case-insensitively', async () => {
    const res = await srv.request('POST', '/v1/users', { body: { handle: 'neal_m' } });
    assert.equal(res.status, 409);
    assertEnvelope(res.json);
    assert.equal(res.json.error, 'Handle is already taken');
  });

  await t.test('signup validation', async () => {
    const cases = [
      [{ handle: 'ab' }, /handle must be 3-20/],
      [{ handle: 'bad handle' }, /handle must be 3-20/],
      [{}, /handle is required/],
      [{ handle: 'okay', admin: true }, /Unknown field/],
      [['handle'], /JSON object/],
    ];
    for (const [body, pattern] of cases) {
      const res = await srv.request('POST', '/v1/users', { body });
      assert.equal(res.status, 400);
      assertEnvelope(res.json);
      assert.match(res.json.error, pattern);
    }
  });

  await t.test('GET /v1/me requires a valid bearer token', async () => {
    const user = await srv.createUser('meuser');
    const me = await srv.request('GET', '/v1/me', { token: user.token });
    assert.equal(me.status, 200);
    assert.deepEqual(
      { id: me.json.data.id, handle: me.json.data.handle, tier: me.json.data.tier },
      { id: user.id, handle: 'meuser', tier: 'bronze' },
    );
    for (const headers of [{}, { authorization: 'Basic abc' }, { authorization: `Bearer ${'0'.repeat(64)}` }]) {
      const res = await srv.request('GET', '/v1/me', { headers });
      assert.equal(res.status, 401);
      assertEnvelope(res.json);
      assert.equal(res.headers.get('www-authenticate'), 'Bearer');
    }
  });

  await t.test('malformed requests', async () => {
    const badJson = await srv.request('POST', '/v1/users', { raw: '{nope', headers: { 'content-type': 'application/json' } });
    assert.equal(badJson.status, 400);
    assert.equal(badJson.json.error, 'Request body is not valid JSON');
    const wrongType = await srv.request('POST', '/v1/users', { raw: 'handle=x', headers: { 'content-type': 'text/plain' } });
    assert.equal(wrongType.status, 415);
    const empty = await srv.request('POST', '/v1/users', {});
    assert.equal(empty.status, 400);
    const huge = await srv.request('POST', '/v1/users', { body: { handle: 'x'.repeat(17 * 1024) } });
    assert.equal(huge.status, 413);
    assertEnvelope(huge.json);
    const notFound = await srv.request('GET', '/v1/nothing');
    assert.equal(notFound.status, 404);
    assertEnvelope(notFound.json);
    const wrongMethod = await srv.request('DELETE', '/v1/users');
    assert.equal(wrongMethod.status, 405);
    assert.equal(wrongMethod.headers.get('allow'), 'POST');
    const dupQuery = await srv.request('GET', '/healthz?a=1&a=2');
    assert.equal(dupQuery.status, 400);
  });
});

test('unexpected errors return a generic 500 and are logged server-side', async (t) => {
  const failingStore = {
    findAll: () => { throw new Error('disk on fire'); },
  };
  const srv = await startServer({ store: failingStore });
  t.after(() => srv.close());
  const res = await srv.request('POST', '/v1/users', { body: { handle: 'anyone' } });
  assert.equal(res.status, 500);
  assert.deepEqual(res.json, { success: false, data: null, error: 'Internal server error' });
  assert.equal(JSON.stringify(res.json).includes('disk on fire'), false);
  assert.equal(srv.logs.length, 1);
  assert.equal(srv.logs[0].msg, 'disk on fire');
  assert.ok(srv.logs[0].stack);
});

test('config resolution and route matching', () => {
  const config = resolveConfig({}, { PORT: '9000', RATE_LIMIT_PER_MINUTE: '5', TRUST_PROXY: '1', ADMIN_TOKEN: 'x' });
  assert.equal(config.port, 9000);
  assert.equal(config.rateLimitPerMinute, 5);
  assert.equal(config.trustProxy, true);
  assert.equal(config.adminToken, 'x');
  assert.equal(resolveConfig({}, {}).port, 8787);
  assert.equal(resolveConfig({}, {}).dataFile, './data/db.json');
  assert.throws(() => resolveConfig({}, { PORT: 'abc' }), /PORT must be/);
  assert.deepEqual(matchRoute('GET', '/v1/groups/abc').params, { id: 'abc' });
  assert.equal(typeof createApp, 'function');
});
