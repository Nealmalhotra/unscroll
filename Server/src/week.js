// ISO-8601 week helpers. Week ids look like "2026-W07".

const DAY_MS = 86_400_000;
const WEEK_ID_RE = /^(\d{4})-W(\d{2})$/;

export const MIN_YEAR = 2000;
export const MAX_YEAR = 2100;

export function isoWeekParts(date) {
  const day = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
  const mondayBased = (new Date(day).getUTCDay() + 6) % 7;
  const thursday = new Date(day + (3 - mondayBased) * DAY_MS);
  const year = thursday.getUTCFullYear();
  const dayOfYear = Math.floor((thursday.getTime() - Date.UTC(year, 0, 1)) / DAY_MS);
  return Object.freeze({ year, week: Math.floor(dayOfYear / 7) + 1 });
}

export function weeksInYear(year) {
  // Dec 28th always falls in the last ISO week of its year.
  return isoWeekParts(new Date(Date.UTC(year, 11, 28))).week;
}

export function formatWeekId({ year, week }) {
  return `${year}-W${String(week).padStart(2, '0')}`;
}

export function currentWeekId(date = new Date()) {
  return formatWeekId(isoWeekParts(date));
}

export function parseWeekId(value) {
  if (typeof value !== 'string') return null;
  const match = WEEK_ID_RE.exec(value);
  if (!match) return null;
  const year = Number(match[1]);
  const week = Number(match[2]);
  if (year < MIN_YEAR || year > MAX_YEAR) return null;
  if (week < 1 || week > weeksInYear(year)) return null;
  return Object.freeze({ year, week });
}
