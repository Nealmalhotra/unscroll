import { test } from 'node:test';
import assert from 'node:assert/strict';
import { startServer } from './helpers.js';

const WEEK = '2026-W43';

test('week stats upsert', async (t) => {
  const srv = await startServer();
  t.after(() => srv.close());
  const user = await srv.createUser('weekly');
  const put = (body) => srv.request('PUT', '/v1/me/week', { token: user.token, body });

  const first = await put({ weekId: WEEK, xp: 120, screenMinutes: 300 });
  assert.equal(first.status, 200);
  assert.deepEqual(
    { ...first.json.data, updatedAt: undefined },
    { weekId: WEEK, xp: 120, screenMinutes: 300, updatedAt: undefined },
  );
  const second = await put({ weekId: WEEK, xp: 500, screenMinutes: 20160 });
  assert.equal(second.json.data.xp, 500);
  assert.equal(srv.app.store.findAll('weekStats').length, 1);

  const invalid = [
    [{ weekId: '2026-W99', xp: 1, screenMinutes: 1 }, /weekId/],
    [{ weekId: WEEK, xp: -1, screenMinutes: 1 }, /xp must be an integer between 0 and 1000000/],
    [{ weekId: WEEK, xp: 1_000_001, screenMinutes: 1 }, /xp/],
    [{ weekId: WEEK, xp: 1.5, screenMinutes: 1 }, /xp/],
    [{ weekId: WEEK, xp: 1, screenMinutes: 20161 }, /screenMinutes must be an integer between 0 and 20160/],
    [{ weekId: WEEK, xp: 1 }, /screenMinutes is required/],
  ];
  for (const [body, pattern] of invalid) {
    const res = await put(body);
    assert.equal(res.status, 400);
    assert.match(res.json.error, pattern);
  }
  const noAuth = await srv.request('PUT', '/v1/me/week', { body: { weekId: WEEK, xp: 1, screenMinutes: 1 } });
  assert.equal(noAuth.status, 401);
});

test('league assignment, standings and cohort cap of 30', async (t) => {
  const srv = await startServer();
  t.after(() => srv.close());
  const users = [];
  for (let i = 0; i < 31; i += 1) users.push(await srv.createUser(`player${String(i).padStart(2, '0')}`));
  for (const [i, u] of users.entries()) {
    await srv.request('PUT', '/v1/me/week', { token: u.token, body: { weekId: WEEK, xp: i * 10, screenMinutes: 60 } });
  }
  const leagues = [];
  for (const u of users) {
    const res = await srv.request('GET', `/v1/me/league?weekId=${WEEK}`, { token: u.token });
    assert.equal(res.status, 200);
    leagues.push(res.json.data);
  }
  const firstCohort = leagues[0].cohortId;
  assert.ok(leagues.slice(0, 30).every((l) => l.cohortId === firstCohort));
  assert.notEqual(leagues[30].cohortId, firstCohort);
  assert.equal(leagues[30].standings.length, 1);

  const again = await srv.request('GET', `/v1/me/league?weekId=${WEEK}`, { token: users[0].token });
  const data = again.json.data;
  assert.equal(data.cohortId, firstCohort, 'assignment is stable');
  assert.deepEqual(Object.keys(data).sort(), ['cohortId', 'demoteCount', 'promoteCount', 'standings', 'tier', 'weekId']);
  assert.equal(data.tier, 'bronze');
  assert.equal(data.promoteCount, 10);
  assert.equal(data.demoteCount, 5);
  assert.equal(data.standings.length, 30);
  assert.deepEqual(data.standings[0], { handle: 'player29', xp: 290, rank: 1, isMe: false });
  assert.deepEqual(data.standings[29], { handle: 'player00', xp: 0, rank: 30, isMe: true });
  assert.equal(data.standings.filter((s) => s.isMe).length, 1);

  const bad = await srv.request('GET', '/v1/me/league?weekId=2026-43', { token: users[0].token });
  assert.equal(bad.status, 400);
  const extra = await srv.request('GET', `/v1/me/league?weekId=${WEEK}&x=1`, { token: users[0].token });
  assert.equal(extra.status, 400);
  const current = await srv.request('GET', '/v1/me/league', { token: users[0].token });
  assert.equal(current.status, 200);
  assert.match(current.json.data.weekId, /^\d{4}-W\d{2}$/);
});

test('admin rollover applies promotions/demotions once', async (t) => {
  const srv = await startServer();
  t.after(() => srv.close());
  const users = [];
  for (let i = 0; i < 20; i += 1) users.push(await srv.createUser(`roll${String(i).padStart(2, '0')}`));
  for (const [i, u] of users.entries()) {
    await srv.request('PUT', '/v1/me/week', { token: u.token, body: { weekId: WEEK, xp: (i + 1) * 5, screenMinutes: 0 } });
    await srv.request('GET', `/v1/me/league?weekId=${WEEK}`, { token: u.token });
  }
  const admin = (body, token = 'test-admin-token') => srv.request('POST', '/v1/admin/rollover', { token, body });

  assert.equal((await admin({ weekId: WEEK }, 'wrong')).status, 401);
  assert.equal((await srv.request('POST', '/v1/admin/rollover', { body: { weekId: WEEK } })).status, 401);
  assert.equal((await admin({ weekId: WEEK }, users[0].token)).status, 401);
  assert.equal((await admin({ weekId: 'bad' })).status, 400);

  const res = await admin({ weekId: WEEK });
  assert.equal(res.status, 200);
  assert.equal(res.json.data.cohortCount, 1);
  const promoted = res.json.data.changes.filter((c) => c.change === 'promote');
  assert.equal(promoted.length, 10);
  assert.equal(res.json.data.changes.filter((c) => c.change === 'demote').length, 0, 'bronze cannot demote');
  assert.deepEqual(promoted[0], { handle: 'roll19', from: 'bronze', to: 'silver', change: 'promote' });

  const me = await srv.request('GET', '/v1/me', { token: users[19].token });
  assert.equal(me.json.data.tier, 'silver');
  const stayed = await srv.request('GET', '/v1/me', { token: users[0].token });
  assert.equal(stayed.json.data.tier, 'bronze');

  assert.equal((await admin({ weekId: WEEK })).status, 409);
  const late = await srv.request('PUT', '/v1/me/week', { token: users[0].token, body: { weekId: WEEK, xp: 1, screenMinutes: 1 } });
  assert.equal(late.status, 409);
  const newcomer = await srv.createUser('latecomer');
  const lateLeague = await srv.request('GET', `/v1/me/league?weekId=${WEEK}`, { token: newcomer.token });
  assert.equal(lateLeague.status, 409);

  const next = await srv.request('GET', '/v1/me/league?weekId=2026-W44', { token: users[19].token });
  assert.equal(next.json.data.tier, 'silver');
});

test('admin API is disabled without ADMIN_TOKEN', async (t) => {
  const srv = await startServer({ adminToken: '' });
  t.after(() => srv.close());
  const res = await srv.request('POST', '/v1/admin/rollover', { token: 'anything', body: { weekId: WEEK } });
  assert.equal(res.status, 403);
  assert.match(res.json.error, /disabled/);
});
