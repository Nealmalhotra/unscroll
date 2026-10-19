import { test } from 'node:test';
import assert from 'node:assert/strict';
import { startServer } from './helpers.js';

const WEEK = '2026-W43';
const INVITE_RE = /^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$/;

test('groups: create, join, list, detail, leave', async (t) => {
  const srv = await startServer();
  t.after(() => srv.close());
  const owner = await srv.createUser('owner');
  const friend = await srv.createUser('friend');
  const outsider = await srv.createUser('outsider');
  const req = (method, path, token, body) => srv.request(method, path, { token, body });

  const created = await req('POST', '/v1/groups', owner.token, { name: '  Study Crew ' });
  assert.equal(created.status, 201);
  const group = created.json.data;
  assert.equal(group.name, 'Study Crew');
  assert.match(group.inviteCode, INVITE_RE);
  assert.equal(group.memberCount, 1);

  assert.equal((await req('POST', '/v1/groups', owner.token, { name: '' })).status, 400);
  assert.equal((await req('POST', '/v1/groups', owner.token, { name: 'x'.repeat(41) })).status, 400);

  const join = await req('POST', '/v1/groups/join', friend.token, { inviteCode: group.inviteCode.toLowerCase() });
  assert.equal(join.status, 200);
  assert.equal(join.json.data.memberCount, 2);
  const rejoin = await req('POST', '/v1/groups/join', friend.token, { inviteCode: group.inviteCode });
  assert.equal(rejoin.json.data.memberCount, 2, 'joining twice is idempotent');
  assert.equal((await req('POST', '/v1/groups/join', friend.token, { inviteCode: 'ZZZZZZZZ' })).status, 404);
  assert.equal((await req('POST', '/v1/groups/join', friend.token, { inviteCode: 'BAD' })).status, 400);

  const list = await req('GET', '/v1/groups', friend.token);
  assert.deepEqual(list.json.data.map((g) => g.id), [group.id]);
  assert.deepEqual((await req('GET', '/v1/groups', outsider.token)).json.data, []);

  await req('PUT', '/v1/me/week', owner.token, { weekId: WEEK, xp: 10, screenMinutes: 100 });
  await req('PUT', '/v1/me/week', friend.token, { weekId: WEEK, xp: 50, screenMinutes: 40 });
  const detail = await req('GET', `/v1/groups/${group.id}?weekId=${WEEK}`, owner.token);
  assert.equal(detail.status, 200);
  assert.deepEqual(detail.json.data.members, [
    { handle: 'friend', xp: 50, screenMinutes: 40 },
    { handle: 'owner', xp: 10, screenMinutes: 100 },
  ]);
  assert.equal(detail.json.data.inviteCode, group.inviteCode);
  assert.deepEqual(detail.json.data.feed, []);

  assert.equal((await req('GET', `/v1/groups/${group.id}`, outsider.token)).status, 403);
  assert.equal((await req('GET', '/v1/groups/00000000-0000-4000-8000-000000000000', owner.token)).status, 404);
  assert.equal((await req('GET', '/v1/groups/not-a-uuid', owner.token)).status, 404);
  assert.equal((await req('POST', `/v1/groups/${group.id}/leave`, outsider.token)).status, 403);
  assert.equal((await req('GET', `/v1/groups/${group.id}?weekId=nope`, owner.token)).status, 400);

  const left = await req('POST', `/v1/groups/${group.id}/leave`, friend.token);
  assert.deepEqual(left.json.data, { id: group.id, left: true, deleted: false });
  assert.equal((await req('GET', `/v1/groups/${group.id}`, friend.token)).status, 403);
  const last = await req('POST', `/v1/groups/${group.id}/leave`, owner.token);
  assert.equal(last.json.data.deleted, true);
  assert.equal((await req('GET', `/v1/groups/${group.id}`, owner.token)).status, 404);
});

test('groups cap membership at 50', async (t) => {
  const srv = await startServer();
  t.after(() => srv.close());
  const owner = await srv.createUser('capowner');
  const group = (await srv.request('POST', '/v1/groups', { token: owner.token, body: { name: 'Big' } })).json.data;
  for (let i = 0; i < 49; i += 1) {
    const u = await srv.createUser(`member${String(i).padStart(2, '0')}`);
    const res = await srv.request('POST', '/v1/groups/join', { token: u.token, body: { inviteCode: group.inviteCode } });
    assert.equal(res.status, 200);
  }
  const extra = await srv.createUser('onetoomany');
  const res = await srv.request('POST', '/v1/groups/join', { token: extra.token, body: { inviteCode: group.inviteCode } });
  assert.equal(res.status, 409);
  assert.match(res.json.error, /full/);
});

test('group feed: append, validation, ordering, cap at 200', async (t) => {
  const srv = await startServer();
  t.after(() => srv.close());
  const owner = await srv.createUser('feeder');
  const outsider = await srv.createUser('lurker');
  const group = (await srv.request('POST', '/v1/groups', { token: owner.token, body: { name: 'Feed' } })).json.data;
  const post = (body, token = owner.token) => srv.request('POST', `/v1/groups/${group.id}/feed`, { token, body });

  const first = await post({ kind: 'sessionCompleted', minutes: 45 });
  assert.equal(first.status, 201);
  assert.equal(first.json.data.handle, 'feeder');
  assert.equal(first.json.data.minutes, 45);
  assert.ok(!Number.isNaN(Date.parse(first.json.data.at)));
  assert.equal((await post({ kind: 'goalMet' })).json.data.minutes, null);

  assert.equal((await post({ kind: 'partyTime' })).status, 400);
  assert.equal((await post({ kind: 'goalMet', minutes: 1441 })).status, 400);
  assert.equal((await post({ minutes: 5 })).status, 400);
  assert.equal((await post({ kind: 'goalMet' }, outsider.token)).status, 403);

  for (let i = 0; i < 205; i += 1) await post({ kind: 'sessionStarted', minutes: i % 1441 });
  const stored = srv.app.store.findById('groups', group.id).feed;
  assert.equal(stored.length, 200);
  assert.equal(stored[stored.length - 1].minutes, 204);

  const detail = (await srv.request('GET', `/v1/groups/${group.id}`, { token: owner.token })).json.data;
  assert.equal(detail.feed.length, 50);
  assert.equal(detail.feed[0].minutes, 204, 'newest first');
  assert.equal(detail.feed[49].minutes, 155);
});
