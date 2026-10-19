// Strict, schema-style input validation. Every failure is a 400 HttpError.

import { HttpError } from './http.js';
import { parseWeekId } from './week.js';

export const HANDLE_RE = /^[A-Za-z0-9_]{3,20}$/;
export const INVITE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
export const INVITE_CODE_LENGTH = 8;
const INVITE_RE = new RegExp(`^[${INVITE_ALPHABET}]{${INVITE_CODE_LENGTH}}$`);
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
// Rejects C0/C1 control characters and the Unicode line/paragraph separators.
const CONTROL_RE = new RegExp('[\\u0000-\\u001f\\u007f-\\u009f\\u2028\\u2029]');

export const bad = (message) => new HttpError(400, message);

export function isPlainObject(value) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return false;
  const proto = Object.getPrototypeOf(value);
  return proto === Object.prototype || proto === null;
}

export function validateObject(input, schema, label = 'body') {
  if (!isPlainObject(input)) throw bad(`Request ${label} must be a JSON object`);
  const unknown = Object.keys(input).filter((key) => !Object.hasOwn(schema, key));
  if (unknown.length > 0) throw bad(`Unknown field(s) in ${label}: ${unknown.join(', ')}`);
  return Object.freeze(
    Object.fromEntries(Object.entries(schema).map(([key, rule]) => [key, rule(input[key], key)])),
  );
}

export const required = (check) => (value, name) => {
  if (value === undefined || value === null) throw bad(`${name} is required`);
  return check(value, name);
};

export const optional = (check) => (value, name) =>
  value === undefined || value === null ? null : check(value, name);

export const intInRange = (min, max) => (value, name) => {
  if (!Number.isInteger(value) || value < min || value > max) {
    throw bad(`${name} must be an integer between ${min} and ${max}`);
  }
  return value;
};

export const oneOf = (allowed) => (value, name) => {
  if (typeof value !== 'string' || !allowed.includes(value)) {
    throw bad(`${name} must be one of: ${allowed.join(', ')}`);
  }
  return value;
};

export function handle(value, name) {
  if (typeof value !== 'string' || !HANDLE_RE.test(value)) {
    throw bad(`${name} must be 3-20 characters using only letters, digits and underscore`);
  }
  return value;
}

export function weekId(value, name) {
  if (parseWeekId(value) === null) {
    throw bad(`${name} must be an ISO week like "2026-W07" (year 2000-2100, valid week number)`);
  }
  return value;
}

export function groupName(value, name) {
  if (typeof value !== 'string') throw bad(`${name} must be a string`);
  const trimmed = value.trim();
  if (trimmed.length < 1 || [...trimmed].length > 40) {
    throw bad(`${name} must be 1-40 characters`);
  }
  if (CONTROL_RE.test(trimmed)) throw bad(`${name} must not contain control characters`);
  return trimmed;
}

export function inviteCode(value, name) {
  const normalized = typeof value === 'string' ? value.trim().toUpperCase() : '';
  if (!INVITE_RE.test(normalized)) {
    throw bad(`${name} must be ${INVITE_CODE_LENGTH} characters from ${INVITE_ALPHABET}`);
  }
  return normalized;
}

export const isUuid = (value) => typeof value === 'string' && UUID_RE.test(value);

export function queryToObject(searchParams) {
  const keys = [...searchParams.keys()];
  if (new Set(keys).size !== keys.length) throw bad('Duplicate query parameters are not allowed');
  return Object.fromEntries(searchParams.entries());
}
