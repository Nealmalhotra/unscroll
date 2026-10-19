// HTTP helpers: error type, envelope, JSON responses and bounded body reading.

export const BODY_LIMIT_BYTES = 16 * 1024;

const BASE_HEADERS = Object.freeze({
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
  'x-content-type-options': 'nosniff',
});

export class HttpError extends Error {
  constructor(status, message, headers = {}) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.headers = Object.freeze({ ...headers });
  }
}

export const ok = (data) => Object.freeze({ status: 200, data });
export const created = (data) => Object.freeze({ status: 201, data });

export function envelope(success, data, error) {
  return { success, data: data ?? null, error: error ?? null };
}

export function sendJson(res, status, body, headers = {}) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    ...BASE_HEADERS,
    ...headers,
    'content-length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

const tooLarge = (limit) =>
  new HttpError(413, `Request body exceeds ${limit} bytes`, { connection: 'close' });

export function readBody(req, limit = BODY_LIMIT_BYTES) {
  const declared = Number(req.headers['content-length']);
  if (Number.isFinite(declared) && declared > limit) {
    req.resume();
    return Promise.reject(tooLarge(limit));
  }
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    let failed = false;
    req.on('data', (chunk) => {
      if (failed) return;
      size += chunk.length;
      if (size > limit) {
        failed = true;
        reject(tooLarge(limit));
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (!failed) resolve(Buffer.concat(chunks).toString('utf8'));
    });
    req.on('error', (err) => {
      if (failed) return;
      failed = true;
      reject(err);
    });
  });
}

const isJsonContentType = (value) =>
  typeof value === 'string' && value.split(';')[0].trim().toLowerCase() === 'application/json';

export function parseJsonBody(raw, contentType) {
  if (raw.length === 0) return {};
  if (!isJsonContentType(contentType)) {
    throw new HttpError(415, 'Content-Type must be application/json');
  }
  try {
    return JSON.parse(raw);
  } catch {
    throw new HttpError(400, 'Request body is not valid JSON');
  }
}
