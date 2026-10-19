import { HttpError, ok } from '../http.js';
import { intInRange, required, validateObject, weekId } from '../validate.js';

export const MAX_XP = 1_000_000;
export const MAX_SCREEN_MINUTES = 20_160;

export const weekStatsId = (userId, week) => `${userId}:${week}`;

export function statsFor(store, userId, week) {
  const record = store.findById('weekStats', weekStatsId(userId, week));
  return { xp: record?.xp ?? 0, screenMinutes: record?.screenMinutes ?? 0 };
}

export function putWeek({ store, user, body, now }) {
  const input = validateObject(body, {
    weekId: required(weekId),
    xp: required(intInRange(0, MAX_XP)),
    screenMinutes: required(intInRange(0, MAX_SCREEN_MINUTES)),
  });
  if (store.findById('rollovers', input.weekId)) {
    throw new HttpError(409, 'This week has already been finalized');
  }
  const id = weekStatsId(user.id, input.weekId);
  const fields = { xp: input.xp, screenMinutes: input.screenMinutes, updatedAt: now().toISOString() };
  const saved = store.findById('weekStats', id)
    ? store.update('weekStats', id, (previous) => ({ ...previous, ...fields }))
    : store.create('weekStats', { id, userId: user.id, weekId: input.weekId, ...fields });
  return ok({
    weekId: saved.weekId,
    xp: saved.xp,
    screenMinutes: saved.screenMinutes,
    updatedAt: saved.updatedAt,
  });
}
