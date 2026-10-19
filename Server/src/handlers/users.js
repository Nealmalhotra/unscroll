import { randomUUID } from 'node:crypto';
import { generateToken, hashTokenHex } from '../auth.js';
import { HttpError, created, ok } from '../http.js';
import { TIERS } from '../league.js';
import { handle, required, validateObject } from '../validate.js';

export function createUser({ store, body, now }) {
  const input = validateObject(body, { handle: required(handle) });
  const handleLower = input.handle.toLowerCase();
  if (store.findAll('users', (u) => u.handleLower === handleLower).length > 0) {
    throw new HttpError(409, 'Handle is already taken');
  }
  const token = generateToken();
  const user = store.create('users', {
    id: randomUUID(),
    handle: input.handle,
    handleLower,
    tokenHash: hashTokenHex(token),
    tier: TIERS[0],
    createdAt: now().toISOString(),
  });
  return created({ id: user.id, handle: user.handle, token });
}

export function getMe({ user }) {
  return ok({ id: user.id, handle: user.handle, tier: user.tier, createdAt: user.createdAt });
}
