// Token generation, hashing and constant-time verification.

import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { HttpError } from './http.js';

const BEARER_RE = /^Bearer ([A-Za-z0-9._~+/=-]{1,512})$/;

export const generateToken = () => randomBytes(32).toString('hex');
export const hashToken = (token) => createHash('sha256').update(token, 'utf8').digest();
export const hashTokenHex = (token) => hashToken(token).toString('hex');

export function parseBearer(header) {
  if (typeof header !== 'string') return null;
  const match = BEARER_RE.exec(header.trim());
  return match ? match[1] : null;
}

export function tokensMatch(provided, expected) {
  return timingSafeEqual(hashToken(provided), hashToken(expected));
}

/** Compares against every user so timing does not reveal where a match was found. */
export function findUserByToken(users, token) {
  const candidate = hashToken(token);
  return users.reduce((found, user) => {
    const stored = Buffer.from(user.tokenHash, 'hex');
    const matches = stored.length === candidate.length && timingSafeEqual(stored, candidate);
    return matches ? user : found;
  }, null);
}

const unauthorized = () =>
  new HttpError(401, 'Missing or invalid bearer token', { 'www-authenticate': 'Bearer' });

export function requireUser(store, header) {
  const token = parseBearer(header);
  if (!token) throw unauthorized();
  const user = findUserByToken(store.findAll('users'), token);
  if (!user) throw unauthorized();
  return user;
}

export function requireAdmin(adminToken, header) {
  if (!adminToken) throw new HttpError(403, 'Admin API is disabled (ADMIN_TOKEN not set)');
  const token = parseBearer(header);
  if (!token || !tokensMatch(token, adminToken)) throw unauthorized();
  return true;
}
