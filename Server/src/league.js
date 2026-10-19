// Pure league logic: tiers, ranking and end-of-week promotion/demotion.

export const TIERS = Object.freeze(['bronze', 'silver', 'gold', 'platinum', 'diamond', 'present']);
export const COHORT_SIZE = 30;
export const PROMOTE_COUNT = 10;
export const DEMOTE_COUNT = 5;
export const MIN_SIZE_FOR_DEMOTION = 15;

export const tierIndex = (tier) => TIERS.indexOf(tier);
export const isTier = (tier) => tierIndex(tier) !== -1;

const compareEntries = (a, b) =>
  b.xp - a.xp || a.handle.toLowerCase().localeCompare(b.handle.toLowerCase()) ||
  String(a.userId).localeCompare(String(b.userId));

/** Sort by xp desc (ties: handle asc) and attach a 1-based sequential rank. */
export function rankStandings(entries) {
  return [...entries]
    .sort(compareEntries)
    .map((entry, index) => Object.freeze({ ...entry, rank: index + 1 }));
}

function nextTier(tier, rank, size, xp) {
  const index = tierIndex(tier);
  const canPromote = index < TIERS.length - 1 && rank <= PROMOTE_COUNT && xp > 0;
  if (canPromote) return TIERS[index + 1];
  const canDemote = index > 0 && size > MIN_SIZE_FOR_DEMOTION && rank > size - DEMOTE_COUNT;
  if (canDemote) return TIERS[index - 1];
  return tier;
}

/**
 * Given a cohort's standings ({userId, xp, rank}) and the cohort tier, return
 * [{userId, from, tier, change}] for every member. Top PROMOTE_COUNT with xp > 0
 * move up (unless top tier); bottom DEMOTE_COUNT move down when the cohort has
 * more than MIN_SIZE_FOR_DEMOTION members (unless bottom tier).
 */
export function resolveWeek(cohortStandings, tier) {
  if (!isTier(tier)) throw new Error(`Unknown tier: ${tier}`);
  if (!Array.isArray(cohortStandings)) throw new Error('cohortStandings must be an array');
  const ordered = [...cohortStandings].sort((a, b) => a.rank - b.rank);
  const size = ordered.length;
  return ordered.map((entry, index) => {
    const to = nextTier(tier, index + 1, size, entry.xp ?? 0);
    const change = to === tier ? 'stay' : tierIndex(to) > tierIndex(tier) ? 'promote' : 'demote';
    return Object.freeze({ userId: entry.userId, from: tier, tier: to, change });
  });
}
