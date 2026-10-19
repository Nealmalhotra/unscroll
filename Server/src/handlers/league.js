import { randomUUID } from 'node:crypto';
import { HttpError, ok } from '../http.js';
import { COHORT_SIZE, DEMOTE_COUNT, PROMOTE_COUNT, rankStandings } from '../league.js';
import { optional, validateObject, weekId } from '../validate.js';
import { currentWeekId } from '../week.js';
import { statsFor } from './weeks.js';

const assignmentId = (userId, week) => `${userId}:${week}`;

export function cohortEntries(store, cohort) {
  return cohort.memberIds
    .map((id) => store.findById('users', id))
    .filter(Boolean)
    .map((member) => ({
      userId: member.id,
      handle: member.handle,
      xp: statsFor(store, member.id, cohort.weekId).xp,
    }));
}

function findOpenCohort(store, week, tier) {
  const open = store.findAll(
    'cohorts',
    (c) => c.weekId === week && c.tier === tier && c.memberIds.length < COHORT_SIZE,
  );
  return open[0] ?? null;
}

function ensureAssignment(store, user, week, now) {
  const existing = store.findById('assignments', assignmentId(user.id, week));
  if (existing) return existing;
  if (store.findById('rollovers', week)) {
    throw new HttpError(409, 'This week has already been finalized');
  }
  const cohort =
    findOpenCohort(store, week, user.tier) ??
    store.create('cohorts', {
      id: randomUUID(),
      weekId: week,
      tier: user.tier,
      memberIds: [],
      createdAt: now().toISOString(),
    });
  store.update('cohorts', cohort.id, (c) => ({ ...c, memberIds: [...c.memberIds, user.id] }));
  return store.create('assignments', {
    id: assignmentId(user.id, week),
    userId: user.id,
    weekId: week,
    tier: user.tier,
    cohortId: cohort.id,
  });
}

export function getLeague({ store, user, query, now }) {
  const input = validateObject(query, { weekId: optional(weekId) }, 'query');
  const week = input.weekId ?? currentWeekId(now());
  const assignment = store.transact(() => ensureAssignment(store, user, week, now));
  const cohort = store.findById('cohorts', assignment.cohortId);
  const standings = rankStandings(cohortEntries(store, cohort)).map((entry) => ({
    handle: entry.handle,
    xp: entry.xp,
    rank: entry.rank,
    isMe: entry.userId === user.id,
  }));
  return ok({
    weekId: week,
    tier: assignment.tier,
    cohortId: cohort.id,
    standings,
    promoteCount: PROMOTE_COUNT,
    demoteCount: DEMOTE_COUNT,
  });
}
