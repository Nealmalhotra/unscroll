import { test } from 'node:test';
import assert from 'node:assert/strict';
import { clientIp, createRateLimiter } from '../src/rateLimit.js';
import { startServer } from './helpers.js';

test('token bucket allows capacity then refills over time', () => {
  let clock = 0;
  const limiter = createRateLimiter({ capacity: 3, windowMs: 3000, now: () => clock });
  assert.equal(limiter.take('ip').allowed, true);
  assert.equal(limiter.take('ip').allowed, true);
  assert.equal(limiter.take('ip').remaining, 0);
  const denied = limiter.take('ip');
  assert.equal(denied.allowed, false);
  assert.equal(denied.retryAfterSec, 1);
  assert.equal(limiter.take('other').allowed, true);
  clock = 1000;
  assert.equal(limiter.take('ip').allowed, true);
  assert.equal(limiter.take('ip').allowed, false);
});

test('limiter sweeps idle keys when the key cap is reached', () => {
  let clock = 0;
  const limiter = createRateLimiter({ capacity: 2, windowMs: 1000, now: () => clock, maxKeys: 2 });
  limiter.take('a');
  limiter.take('b');
  clock = 10_000;
  limiter.take('c');
  assert.equal(limiter.size(), 1);
});

test('limiter rejects invalid capacity', () => {
  assert.throws(() => createRateLimiter({ capacity: 0 }), /positive integer/);
});

test('clientIp honours proxy headers only when trusted', () => {
  const req = { headers: { 'x-forwarded-for': '1.1.1.1, 2.2.2.2' }, socket: { remoteAddress: '9.9.9.9' } };
  assert.equal(clientIp(req, false), '9.9.9.9');
  assert.equal(clientIp(req, true), '2.2.2.2');
  assert.equal(clientIp({ headers: { 'fly-client-ip': '3.3.3.3' }, socket: {} }, true), '3.3.3.3');
  assert.equal(clientIp({ headers: {}, socket: {} }, true), 'unknown');
});

test('server returns 429 with Retry-After once the bucket is empty', async (t) => {
  const srv = await startServer({ rateLimitPerMinute: 5 });
  t.after(() => srv.close());
  for (let i = 0; i < 5; i += 1) {
    const res = await srv.request('GET', '/v1/me');
    assert.equal(res.status, 401);
  }
  const limited = await srv.request('GET', '/v1/me');
  assert.equal(limited.status, 429);
  assert.deepEqual(limited.json, { success: false, data: null, error: 'Too many requests, slow down' });
  assert.ok(Number(limited.headers.get('retry-after')) >= 1);
  const health = await srv.request('GET', '/healthz');
  assert.equal(health.status, 200);
});
