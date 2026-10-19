// Per-key token bucket. Buckets are replaced (never mutated) on every take.

export const DEFAULT_CAPACITY = 60;
const WINDOW_MS = 60_000;
const DEFAULT_MAX_KEYS = 10_000;

const refill = (bucket, at, capacity, ratePerMs) =>
  Math.min(capacity, bucket.tokens + Math.max(0, at - bucket.updatedAt) * ratePerMs);

export function createRateLimiter({
  capacity = DEFAULT_CAPACITY,
  windowMs = WINDOW_MS,
  now = Date.now,
  maxKeys = DEFAULT_MAX_KEYS,
} = {}) {
  if (!Number.isInteger(capacity) || capacity < 1) {
    throw new Error('Rate limit capacity must be a positive integer');
  }
  const ratePerMs = capacity / windowMs;
  const buckets = new Map();

  const sweep = (at) => {
    for (const [key, bucket] of buckets) {
      if (refill(bucket, at, capacity, ratePerMs) >= capacity) buckets.delete(key);
    }
  };

  const take = (key) => {
    const at = now();
    if (buckets.size >= maxKeys && !buckets.has(key)) sweep(at);
    const previous = buckets.get(key) ?? { tokens: capacity, updatedAt: at };
    const tokens = refill(previous, at, capacity, ratePerMs);
    if (tokens < 1) {
      buckets.set(key, Object.freeze({ tokens, updatedAt: at }));
      const retryAfterSec = Math.max(1, Math.ceil((1 - tokens) / ratePerMs / 1000));
      return Object.freeze({ allowed: false, remaining: 0, retryAfterSec });
    }
    buckets.set(key, Object.freeze({ tokens: tokens - 1, updatedAt: at }));
    return Object.freeze({ allowed: true, remaining: Math.floor(tokens - 1), retryAfterSec: 0 });
  };

  return Object.freeze({ take, size: () => buckets.size, capacity });
}

export function clientIp(req, trustProxy = false) {
  if (trustProxy) {
    const forwarded = req.headers['fly-client-ip'] ?? req.headers['x-forwarded-for'];
    if (typeof forwarded === 'string' && forwarded.length > 0) {
      const parts = forwarded.split(',').map((part) => part.trim()).filter(Boolean);
      if (parts.length > 0) return parts[parts.length - 1];
    }
  }
  return req.socket?.remoteAddress ?? 'unknown';
}
