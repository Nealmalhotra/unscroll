import { randomInt, randomUUID } from 'node:crypto';
import { HttpError, created, ok } from '../http.js';
import {
  INVITE_ALPHABET,
  INVITE_CODE_LENGTH,
  groupName,
  intInRange,
  inviteCode,
  isUuid,
  oneOf,
  optional,
  required,
  validateObject,
  weekId,
} from '../validate.js';
import { currentWeekId } from '../week.js';
import { statsFor } from './weeks.js';

export const MAX_MEMBERS = 50;
export const FEED_CAP = 200;
export const FEED_PAGE = 50;
export const FEED_KINDS = Object.freeze([
  'sessionStarted',
  'sessionCompleted',
  'sessionBroken',
  'goalMet',
  'goalMissed',
]);
const MAX_CODE_ATTEMPTS = 20;

const summary = (g) => ({ id: g.id, name: g.name, inviteCode: g.inviteCode, memberCount: g.memberIds.length });

const randomCode = () =>
  Array.from({ length: INVITE_CODE_LENGTH }, () => INVITE_ALPHABET[randomInt(INVITE_ALPHABET.length)]).join('');

function uniqueInviteCode(store) {
  for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt += 1) {
    const code = randomCode();
    if (store.findAll('groups', (g) => g.inviteCode === code).length === 0) return code;
  }
  throw new Error('Could not generate a unique invite code');
}

function requireMember(store, groupId, user) {
  const group = isUuid(groupId) ? store.findById('groups', groupId) : null;
  if (!group) throw new HttpError(404, 'Group not found');
  if (!group.memberIds.includes(user.id)) throw new HttpError(403, 'You are not a member of this group');
  return group;
}

export function createGroup({ store, user, body, now }) {
  const input = validateObject(body, { name: required(groupName) });
  const group = store.create('groups', {
    id: randomUUID(),
    name: input.name,
    inviteCode: uniqueInviteCode(store),
    ownerId: user.id,
    memberIds: [user.id],
    feed: [],
    createdAt: now().toISOString(),
  });
  return created(summary(group));
}

export function listGroups({ store, user }) {
  return ok(store.findAll('groups', (g) => g.memberIds.includes(user.id)).map(summary));
}

export function joinGroup({ store, user, body }) {
  const input = validateObject(body, { inviteCode: required(inviteCode) });
  const group = store.findAll('groups', (g) => g.inviteCode === input.inviteCode)[0];
  if (!group) throw new HttpError(404, 'No group matches that invite code');
  if (group.memberIds.includes(user.id)) return ok(summary(group));
  if (group.memberIds.length >= MAX_MEMBERS) {
    throw new HttpError(409, `Group is full (max ${MAX_MEMBERS} members)`);
  }
  const updated = store.update('groups', group.id, (g) => ({ ...g, memberIds: [...g.memberIds, user.id] }));
  return ok(summary(updated));
}

export function leaveGroup({ store, user, params, body }) {
  validateObject(body, {});
  const group = requireMember(store, params.id, user);
  const remaining = group.memberIds.filter((id) => id !== user.id);
  if (remaining.length === 0) {
    store.remove('groups', group.id);
    return ok({ id: group.id, left: true, deleted: true });
  }
  store.update('groups', group.id, (g) => ({ ...g, memberIds: remaining }));
  return ok({ id: group.id, left: true, deleted: false });
}

function memberRows(store, group, week) {
  return group.memberIds
    .map((id) => store.findById('users', id))
    .filter(Boolean)
    .map((member) => ({ handle: member.handle, ...statsFor(store, member.id, week) }))
    .sort((a, b) => b.xp - a.xp || a.handle.toLowerCase().localeCompare(b.handle.toLowerCase()));
}

export function getGroup({ store, user, params, query, now }) {
  const input = validateObject(query, { weekId: optional(weekId) }, 'query');
  const group = requireMember(store, params.id, user);
  const week = input.weekId ?? currentWeekId(now());
  return ok({
    id: group.id,
    name: group.name,
    inviteCode: group.inviteCode,
    weekId: week,
    members: memberRows(store, group, week),
    feed: group.feed.slice(-FEED_PAGE).toReversed(),
  });
}

export function postFeed({ store, user, params, body, now }) {
  const input = validateObject(body, {
    kind: required(oneOf(FEED_KINDS)),
    minutes: optional(intInRange(0, 1440)),
  });
  const group = requireMember(store, params.id, user);
  const event = { handle: user.handle, kind: input.kind, minutes: input.minutes, at: now().toISOString() };
  store.update('groups', group.id, (g) => ({ ...g, feed: [...g.feed, event].slice(-FEED_CAP) }));
  return created(event);
}
