// JSON-file repository. State is deeply frozen; every write builds a new state
// object and persists it atomically (temp file + rename).

import { existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { randomBytes } from 'node:crypto';

export const COLLECTIONS = Object.freeze([
  'users',
  'weekStats',
  'cohorts',
  'assignments',
  'groups',
  'rollovers',
]);

export const DEFAULT_DATA_FILE = './data/db.json';

export function deepFreeze(value) {
  if (value !== null && typeof value === 'object' && !Object.isFrozen(value)) {
    Object.values(value).forEach(deepFreeze);
    Object.freeze(value);
  }
  return value;
}

const emptyState = () => Object.fromEntries(COLLECTIONS.map((name) => [name, {}]));

function isRecordMap(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

export function loadState(filePath) {
  if (!existsSync(filePath)) return deepFreeze(emptyState());
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(filePath, 'utf8'));
  } catch (err) {
    throw new Error(`Data file ${filePath} is not valid JSON: ${err.message}`);
  }
  if (!isRecordMap(parsed)) throw new Error(`Data file ${filePath} must contain a JSON object`);
  const picked = COLLECTIONS.map((name) => {
    const records = parsed[name] ?? {};
    if (!isRecordMap(records)) throw new Error(`Collection "${name}" in ${filePath} is malformed`);
    return [name, records];
  });
  return deepFreeze(Object.fromEntries(picked));
}

export function writeAtomic(filePath, state) {
  mkdirSync(dirname(filePath), { recursive: true });
  const tmp = `${filePath}.${process.pid}.${randomBytes(6).toString('hex')}.tmp`;
  try {
    writeFileSync(tmp, JSON.stringify(state), { mode: 0o600, flush: true });
    renameSync(tmp, filePath);
  } catch (err) {
    rmSync(tmp, { force: true });
    throw err;
  }
}

export function createStore(dataFile = process.env.DATA_FILE || DEFAULT_DATA_FILE) {
  const filePath = resolve(dataFile);
  let state = loadState(filePath);
  let txDepth = 0;

  const persist = () => {
    if (txDepth === 0) writeAtomic(filePath, state);
  };

  const commit = (next) => {
    const previous = state;
    state = deepFreeze(next);
    try {
      persist();
    } catch (err) {
      state = previous;
      throw err;
    }
  };

  const collection = (name) => {
    if (!COLLECTIONS.includes(name)) throw new Error(`Unknown collection: ${name}`);
    return state[name];
  };

  const findById = (name, id) => {
    const records = collection(name);
    return Object.hasOwn(records, id) ? records[id] : null;
  };

  const withRecord = (name, id, record) => ({
    ...state,
    [name]: { ...collection(name), [id]: record },
  });

  return Object.freeze({
    filePath,
    findAll: (name, predicate = () => true) => Object.values(collection(name)).filter(predicate),
    findById,
    create(name, record) {
      if (typeof record?.id !== 'string' || record.id.length === 0) {
        throw new Error('Records must have a non-empty string id');
      }
      if (findById(name, record.id)) throw new Error(`${name}/${record.id} already exists`);
      const frozen = deepFreeze({ ...record });
      commit(withRecord(name, record.id, frozen));
      return frozen;
    },
    update(name, id, updater) {
      const current = findById(name, id);
      if (!current) throw new Error(`${name}/${id} not found`);
      const next = deepFreeze({ ...updater(current), id });
      commit(withRecord(name, id, next));
      return next;
    },
    remove(name, id) {
      if (!findById(name, id)) return false;
      const { [id]: _removed, ...rest } = collection(name);
      commit({ ...state, [name]: rest });
      return true;
    },
    transact(fn) {
      const snapshot = state;
      txDepth += 1;
      let result;
      try {
        result = fn();
      } catch (err) {
        state = snapshot;
        throw err;
      } finally {
        txDepth -= 1;
      }
      try {
        persist();
      } catch (err) {
        state = snapshot;
        throw err;
      }
      return result;
    },
  });
}
