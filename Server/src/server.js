// HTTP wiring: config, rate limiting, auth, body parsing, envelope responses.

import { createServer } from 'node:http';
import { pathToFileURL } from 'node:url';
import { requireAdmin, requireUser } from './auth.js';
import { BODY_LIMIT_BYTES, HttpError, envelope, parseJsonBody, readBody, sendJson } from './http.js';
import { DEFAULT_CAPACITY, clientIp, createRateLimiter } from './rateLimit.js';
import { matchRoute } from './routes.js';
import { DEFAULT_DATA_FILE, createStore } from './store.js';
import { queryToObject } from './validate.js';

export const DEFAULT_PORT = 8787;
const BODY_METHODS = new Set(['POST', 'PUT', 'PATCH']);
const UNLIMITED_PATHS = new Set(['/healthz']);

function parsePositiveInt(value, fallback, name) {
  if (value === undefined || value === '') return fallback;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 0) throw new Error(`${name} must be a non-negative integer`);
  return parsed;
}

export function resolveConfig(options = {}, env = process.env) {
  return Object.freeze({
    port: options.port ?? parsePositiveInt(env.PORT, DEFAULT_PORT, 'PORT'),
    host: options.host ?? env.HOST ?? '0.0.0.0',
    dataFile: options.dataFile ?? env.DATA_FILE ?? DEFAULT_DATA_FILE,
    adminToken: options.adminToken ?? env.ADMIN_TOKEN ?? '',
    rateLimitPerMinute:
      options.rateLimitPerMinute ??
      parsePositiveInt(env.RATE_LIMIT_PER_MINUTE, DEFAULT_CAPACITY, 'RATE_LIMIT_PER_MINUTE'),
    trustProxy: options.trustProxy ?? env.TRUST_PROXY === '1',
    now: options.now ?? (() => new Date()),
    log: options.log ?? ((entry) => console.error(JSON.stringify(entry))),
  });
}

function enforceRateLimit(limiter, req, config) {
  const result = limiter.take(clientIp(req, config.trustProxy));
  if (!result.allowed) {
    throw new HttpError(429, 'Too many requests, slow down', {
      'retry-after': String(result.retryAfterSec),
    });
  }
}

function authenticate(route, req, app) {
  const header = req.headers.authorization;
  if (route.auth === 'user') return requireUser(app.store, header);
  if (route.auth === 'admin') requireAdmin(app.config.adminToken, header);
  return null;
}

async function dispatch(req, app) {
  const url = new URL(req.url ?? '/', 'http://localhost');
  if (!UNLIMITED_PATHS.has(url.pathname)) enforceRateLimit(app.limiter, req, app.config);
  const match = matchRoute(req.method, url.pathname);
  const user = authenticate(match.route, req, app);
  const body = BODY_METHODS.has(req.method)
    ? parseJsonBody(await readBody(req, BODY_LIMIT_BYTES), req.headers['content-type'])
    : {};
  return match.route.handler({
    store: app.store,
    user,
    body,
    query: queryToObject(url.searchParams),
    params: match.params,
    now: app.config.now,
  });
}

function sendError(res, req, err, log) {
  if (res.headersSent) {
    res.destroy();
    return;
  }
  if (err instanceof HttpError) {
    sendJson(res, err.status, envelope(false, null, err.message), err.headers);
    return;
  }
  log({ level: 'error', msg: err?.message, stack: err?.stack, method: req.method, url: req.url });
  sendJson(res, 500, envelope(false, null, 'Internal server error'));
}

export function createApp(options = {}) {
  const config = resolveConfig(options);
  const store = options.store ?? createStore(config.dataFile);
  const limiter = createRateLimiter({ capacity: Math.max(1, config.rateLimitPerMinute) });
  const app = Object.freeze({ config, store, limiter });
  const server = createServer(async (req, res) => {
    try {
      const result = await dispatch(req, app);
      sendJson(res, result.status, envelope(true, result.data, null));
    } catch (err) {
      sendError(res, req, err, config.log);
    }
  });
  server.requestTimeout = 15_000;
  server.headersTimeout = 10_000;
  return Object.freeze({ ...app, server });
}

export function start(options = {}) {
  const app = createApp(options);
  app.server.listen(app.config.port, app.config.host, () => {
    const { port } = app.server.address();
    process.stdout.write(`${JSON.stringify({ level: 'info', msg: 'unscroll server listening', port })}\n`);
  });
  const shutdown = () => app.server.close(() => process.exit(0));
  process.once('SIGTERM', shutdown);
  process.once('SIGINT', shutdown);
  return app;
}

const isMain = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) start();
