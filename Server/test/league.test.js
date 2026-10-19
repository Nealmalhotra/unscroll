import { test } from 'node:test';
import assert from 'node:assert/strict';
import { TIERS, isTier, rankStandings, resolveWeek } from '../src/league.js';

const cohort = (size, xpFor = (i) => (size - i) * 10) =>
  rankStandings(Array.from({ length: size }, (_, i) => ({ userId: `u${i}`, handle: `user${i}`, xp: xpFor(i) })));

const counts = (results) =>
  results.reduce((acc, r) => ({ ...acc, [r.change]: (acc[r.change] ?? 0) + 1 }), {});

test('rankStandings sorts by xp desc then handle, without mutating input', () => {
  const input = Object.freeze([
    Object.freeze({ userId: 'a', handle: 'zed', xp: 5 }),
    Object.freeze({ userId: 'b', handle: 'Amy', xp: 5 }),
    Object.freeze({ userId: 'c', handle: 'bob', xp: 9 }),
  ]);
  const ranked = rankStandings(input);
  assert.deepEqual(ranked.map((r) => [r.handle, r.rank]), [['bob', 1], ['Amy', 2], ['zed', 3]]);
  assert.equal(input[0].handle, 'zed');
});

test('full cohort of 30: top 10 promote, bottom 5 demote', () => {
  const results = resolveWeek(cohort(30), 'gold');
  assert.deepEqual(counts(results), { promote: 10, stay: 15, demote: 5 });
  assert.equal(results[0].tier, 'platinum');
  assert.equal(results[9].tier, 'platinum');
  assert.equal(results[10].tier, 'gold');
  assert.equal(results[25].tier, 'silver');
  assert.equal(results[29].from, 'gold');
});

test('no demotion when cohort size is 15 or fewer', () => {
  assert.deepEqual(counts(resolveWeek(cohort(15), 'gold')), { promote: 10, stay: 5 });
  assert.deepEqual(counts(resolveWeek(cohort(16), 'gold')), { promote: 10, stay: 1, demote: 5 });
});

test('top tier never promotes; bottom tier never demotes', () => {
  assert.deepEqual(counts(resolveWeek(cohort(30), 'present')), { stay: 25, demote: 5 });
  assert.deepEqual(counts(resolveWeek(cohort(30), 'bronze')), { promote: 10, stay: 20 });
});

test('users with zero xp are not promoted', () => {
  const results = resolveWeek(cohort(3, () => 0), 'bronze');
  assert.deepEqual(counts(results), { stay: 3 });
});

test('small and empty cohorts', () => {
  assert.deepEqual(resolveWeek([], 'silver'), []);
  const one = resolveWeek(cohort(1), 'silver');
  assert.deepEqual(one, [{ userId: 'u0', from: 'silver', tier: 'gold', change: 'promote' }]);
});

test('resolveWeek orders by rank even if input is shuffled', () => {
  const shuffled = [...cohort(20)].reverse();
  const results = resolveWeek(shuffled, 'silver');
  assert.equal(results[0].userId, 'u0');
  assert.equal(results[0].change, 'promote');
  assert.equal(results[19].change, 'demote');
});

test('resolveWeek validates arguments', () => {
  assert.throws(() => resolveWeek([], 'mythic'), /Unknown tier/);
  assert.throws(() => resolveWeek(null, 'gold'), /must be an array/);
  assert.equal(isTier('present'), true);
  assert.equal(TIERS.length, 6);
});
