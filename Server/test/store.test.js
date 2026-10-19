import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync, rmSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { createStore, deepFreeze, loadState } from '../src/store.js';
import { makeTempDir } from './helpers.js';

const tempStore = (t) => {
  const dir = makeTempDir();
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  return { dir, file: join(dir, 'nested', 'db.json') };
};

test('create / findById / findAll / update / remove', (t) => {
  const { file } = tempStore(t);
  const store = createStore(file);
  const created = store.create('users', { id: 'u1', handle: 'neal', tier: 'bronze' });
  store.create('users', { id: 'u2', handle: 'amy', tier: 'gold' });
  assert.equal(store.findById('users', 'u1').handle, 'neal');
  assert.equal(store.findById('users', 'missing'), null);
  assert.equal(store.findAll('users').length, 2);
  assert.deepEqual(store.findAll('users', (u) => u.tier === 'gold').map((u) => u.id), ['u2']);
  const updated = store.update('users', 'u1', (u) => ({ ...u, tier: 'silver' }));
  assert.equal(updated.tier, 'silver');
  assert.equal(created.tier, 'bronze', 'previous copy is untouched');
  assert.equal(store.remove('users', 'u2'), true);
  assert.equal(store.remove('users', 'u2'), false);
  assert.equal(store.findAll('users').length, 1);
});

test('records are deeply frozen and cannot be mutated', (t) => {
  const { file } = tempStore(t);
  const store = createStore(file);
  const group = store.create('groups', { id: 'g', memberIds: ['a'] });
  assert.throws(() => { group.memberIds.push('b'); }, TypeError);
  assert.throws(() => { store.findById('groups', 'g').name = 'x'; }, TypeError);
  assert.equal(deepFreeze(5), 5);
});

test('persists atomically and reloads from disk', (t) => {
  const { file } = tempStore(t);
  const store = createStore(file);
  store.create('users', { id: 'u1', handle: 'neal' });
  const leftovers = readdirSync(join(file, '..')).filter((f) => f.endsWith('.tmp'));
  assert.deepEqual(leftovers, []);
  const reloaded = createStore(file);
  assert.equal(reloaded.findById('users', 'u1').handle, 'neal');
  assert.deepEqual(Object.keys(JSON.parse(readFileSync(file, 'utf8'))).sort(), [
    'assignments', 'cohorts', 'groups', 'rollovers', 'users', 'weekStats',
  ]);
});

test('transact batches writes and rolls back on error', (t) => {
  const { file } = tempStore(t);
  const store = createStore(file);
  const result = store.transact(() => {
    store.create('users', { id: 'a' });
    store.create('users', { id: 'b' });
    assert.equal(existsSync(file), false, 'nothing written mid-transaction');
    return 'done';
  });
  assert.equal(result, 'done');
  assert.equal(createStore(file).findAll('users').length, 2);
  assert.throws(() => store.transact(() => {
    store.create('users', { id: 'c' });
    throw new Error('boom');
  }), /boom/);
  assert.equal(store.findById('users', 'c'), null);
});

test('rejects invalid operations', (t) => {
  const { file } = tempStore(t);
  const store = createStore(file);
  assert.throws(() => store.findAll('nope'), /Unknown collection/);
  assert.throws(() => store.create('users', { handle: 'x' }), /string id/);
  store.create('users', { id: 'a' });
  assert.throws(() => store.create('users', { id: 'a' }), /already exists/);
  assert.throws(() => store.update('users', 'zzz', (u) => u), /not found/);
});

test('failed write keeps previous in-memory state', (t) => {
  const { dir } = tempStore(t);
  const blocker = join(dir, 'blocker');
  writeFileSync(blocker, 'file, not a dir');
  const store = createStore(join(blocker, 'db.json'));
  assert.throws(() => store.create('users', { id: 'a' }));
  assert.equal(store.findById('users', 'a'), null);
  assert.throws(() => store.transact(() => store.create('users', { id: 'b' })));
  assert.equal(store.findById('users', 'b'), null);
});

test('loadState fails fast on corrupt or malformed files', (t) => {
  const { dir } = tempStore(t);
  mkdirSync(dir, { recursive: true });
  const file = join(dir, 'bad.json');
  writeFileSync(file, '{not json');
  assert.throws(() => loadState(file), /not valid JSON/);
  writeFileSync(file, '[]');
  assert.throws(() => loadState(file), /must contain a JSON object/);
  writeFileSync(file, '{"users": 5}');
  assert.throws(() => loadState(file), /malformed/);
  writeFileSync(file, '{"users": {}}');
  assert.deepEqual(loadState(file).groups, {});
});
