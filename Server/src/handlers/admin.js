import { HttpError, ok } from '../http.js';
import { rankStandings, resolveWeek } from '../league.js';
import { required, validateObject, weekId } from '../validate.js';
import { cohortEntries } from './league.js';

function applyCohort(store, cohort) {
  const results = resolveWeek(rankStandings(cohortEntries(store, cohort)), cohort.tier);
  return results
    .filter((result) => result.change !== 'stay')
    .map((result) => {
      const updated = store.update('users', result.userId, (u) => ({ ...u, tier: result.tier }));
      return { handle: updated.handle, from: result.from, to: result.tier, change: result.change };
    });
}

export function rollover({ store, body, now }) {
  const input = validateObject(body, { weekId: required(weekId) });
  return store.transact(() => {
    if (store.findById('rollovers', input.weekId)) {
      throw new HttpError(409, 'This week has already been rolled over');
    }
    const cohorts = store.findAll('cohorts', (c) => c.weekId === input.weekId);
    const changes = cohorts.flatMap((cohort) => applyCohort(store, cohort));
    const appliedAt = now().toISOString();
    store.create('rollovers', { id: input.weekId, appliedAt, changeCount: changes.length });
    return ok({ weekId: input.weekId, appliedAt, cohortCount: cohorts.length, changes });
  });
}
