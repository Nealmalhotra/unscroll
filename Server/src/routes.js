// Route table and matching. Handlers receive a context object and return
// {status, data}; they throw HttpError for client errors.

import { HttpError, ok } from './http.js';
import { rollover } from './handlers/admin.js';
import { createGroup, getGroup, joinGroup, leaveGroup, listGroups, postFeed } from './handlers/groups.js';
import { getLeague } from './handlers/league.js';
import { createUser, getMe } from './handlers/users.js';
import { putWeek } from './handlers/weeks.js';

const health = () => ok({ ok: true });

const route = (method, path, handler, options = {}) =>
  Object.freeze({
    method,
    segments: Object.freeze(path.split('/').filter(Boolean)),
    handler,
    auth: options.auth ?? 'user',
  });

export const ROUTES = Object.freeze([
  route('GET', '/healthz', health, { auth: 'none' }),
  route('POST', '/v1/users', createUser, { auth: 'none' }),
  route('GET', '/v1/me', getMe),
  route('PUT', '/v1/me/week', putWeek),
  route('GET', '/v1/me/league', getLeague),
  route('GET', '/v1/groups', listGroups),
  route('POST', '/v1/groups', createGroup),
  route('POST', '/v1/groups/join', joinGroup),
  route('GET', '/v1/groups/:id', getGroup),
  route('POST', '/v1/groups/:id/leave', leaveGroup),
  route('POST', '/v1/groups/:id/feed', postFeed),
  route('POST', '/v1/admin/rollover', rollover, { auth: 'admin' }),
]);

function matchSegments(pattern, actual) {
  if (pattern.length !== actual.length) return null;
  const pairs = pattern.map((part, i) => [part, actual[i]]);
  if (!pairs.every(([part, value]) => part.startsWith(':') || part === value)) return null;
  return Object.freeze(
    Object.fromEntries(pairs.filter(([part]) => part.startsWith(':')).map(([p, v]) => [p.slice(1), v])),
  );
}

export function matchRoute(method, pathname, routes = ROUTES) {
  const actual = pathname.split('/').filter(Boolean);
  const candidates = routes
    .map((r) => ({ route: r, params: matchSegments(r.segments, actual) }))
    .filter((c) => c.params !== null);
  if (candidates.length === 0) throw new HttpError(404, 'Route not found');
  const exact = candidates.find((c) => c.route.method === method);
  if (exact) return exact;
  const allow = [...new Set(candidates.map((c) => c.route.method))].join(', ');
  throw new HttpError(405, 'Method not allowed', { allow });
}
