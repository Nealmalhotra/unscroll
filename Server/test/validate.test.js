import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  groupName,
  handle,
  intInRange,
  inviteCode,
  isPlainObject,
  isUuid,
  oneOf,
  optional,
  queryToObject,
  required,
  validateObject,
  weekId,
} from '../src/validate.js';
import { currentWeekId, isoWeekParts, parseWeekId, weeksInYear } from '../src/week.js';

const throws400 = (fn, pattern) =>
  assert.throws(fn, (err) => err.status === 400 && (!pattern || pattern.test(err.message)));

test('handle accepts 3-20 chars of [A-Za-z0-9_]', () => {
  assert.equal(handle('abc', 'h'), 'abc');
  assert.equal(handle('A_b_9'.padEnd(20, 'x'), 'h'), 'A_b_9xxxxxxxxxxxxxxx');
  for (const bad of ['ab', 'a'.repeat(21), 'has space', 'émoji', 'dash-no', 12, null, '']) {
    throws400(() => handle(bad, 'handle'), /handle must be 3-20/);
  }
});

test('intInRange enforces integers and bounds', () => {
  const check = intInRange(0, 10);
  assert.equal(check(0, 'n'), 0);
  assert.equal(check(10, 'n'), 10);
  for (const bad of [-1, 11, 1.5, '3', NaN, Infinity, true]) {
    throws400(() => check(bad, 'n'), /n must be an integer between 0 and 10/);
  }
});

test('required / optional wrappers', () => {
  throws400(() => required(handle)(undefined, 'handle'), /handle is required/);
  throws400(() => required(handle)(null, 'handle'), /handle is required/);
  assert.equal(optional(intInRange(0, 5))(undefined, 'm'), null);
  assert.equal(optional(intInRange(0, 5))(null, 'm'), null);
  assert.equal(optional(intInRange(0, 5))(3, 'm'), 3);
});

test('oneOf restricts to allowed strings', () => {
  assert.equal(oneOf(['a', 'b'])('a', 'k'), 'a');
  throws400(() => oneOf(['a', 'b'])('c', 'kind'), /kind must be one of: a, b/);
  throws400(() => oneOf(['a'])(1, 'kind'));
});

test('validateObject rejects non-objects, unknown and prototype keys', () => {
  const schema = { handle: required(handle) };
  assert.deepEqual(validateObject({ handle: 'neal' }, schema), { handle: 'neal' });
  for (const bad of [null, [], 'str', 5]) throws400(() => validateObject(bad, schema), /JSON object/);
  throws400(() => validateObject({ handle: 'neal', extra: 1 }, schema), /Unknown field\(s\) in body: extra/);
  throws400(() => validateObject(JSON.parse('{"handle":"neal","__proto__":{}}'), schema), /__proto__/);
  throws400(() => validateObject({ handle: 'neal', toString: 1 }, schema), /toString/);
  assert.equal(Object.isFrozen(validateObject({ handle: 'neal' }, schema)), true);
  assert.equal(isPlainObject(Object.create(null)), true);
  assert.equal(isPlainObject(new Date()), false);
});

test('groupName trims and bounds length', () => {
  assert.equal(groupName('  Friends  ', 'name'), 'Friends');
  assert.equal(groupName('x'.repeat(40), 'name').length, 40);
  throws400(() => groupName('   ', 'name'), /1-40/);
  throws400(() => groupName('x'.repeat(41), 'name'), /1-40/);
  throws400(() => groupName(5, 'name'), /string/);
  throws400(() => groupName('bad\nname', 'name'), /control/);
});

test('inviteCode normalizes case and rejects ambiguous characters', () => {
  assert.equal(inviteCode('abcdefgh', 'c'), 'ABCDEFGH');
  for (const bad of ['ABCDEFG', 'ABCDEFGHJ', 'ABCDEFG0', 'ABCDEFGI', 'ABCDEFGL', 'ABCDEFGO', 'ABCDEFG1', 7]) {
    throws400(() => inviteCode(bad, 'inviteCode'), /inviteCode must be 8 characters/);
  }
});

test('weekId validation follows ISO weeks', () => {
  assert.equal(weekId('2026-W01', 'weekId'), '2026-W01');
  assert.equal(weekId('2026-W53', 'weekId'), '2026-W53');
  assert.equal(weekId('2020-W53', 'weekId'), '2020-W53');
  for (const bad of ['2021-W53', '2026-W00', '2026-W54', '2026-w01', '2026W01', '1999-W10', '2101-W01', '26-W01', 202601]) {
    throws400(() => weekId(bad, 'weekId'), /ISO week/);
  }
});

test('week helpers compute ISO weeks across year boundaries', () => {
  assert.deepEqual(isoWeekParts(new Date('2021-01-03T12:00:00Z')), { year: 2020, week: 53 });
  assert.deepEqual(isoWeekParts(new Date('2024-12-30T00:00:00Z')), { year: 2025, week: 1 });
  assert.equal(currentWeekId(new Date('2026-10-19T08:00:00Z')), '2026-W43');
  assert.equal(weeksInYear(2026), 53);
  assert.equal(weeksInYear(2021), 52);
  assert.equal(parseWeekId(null), null);
  assert.match(currentWeekId(), /^\d{4}-W\d{2}$/);
});

test('isUuid and queryToObject', () => {
  assert.equal(isUuid('123e4567-e89b-42d3-a456-426614174000'), true);
  assert.equal(isUuid('nope'), false);
  assert.deepEqual(queryToObject(new URLSearchParams('weekId=2026-W01')), { weekId: '2026-W01' });
  throws400(() => queryToObject(new URLSearchParams('a=1&a=2')), /Duplicate/);
});
