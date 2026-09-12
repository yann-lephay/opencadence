// Standalone collector. Never host the local Next.js journal alongside this service.
import { createServer } from 'node:http';
import { DatabaseSync } from 'node:sqlite';
import { createHash } from 'node:crypto';
import { mkdirSync, chmodSync, rmSync, renameSync, existsSync, statSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { isDeepStrictEqual } from 'node:util';

const hash = value => createHash('sha256').update(value).digest('hex');
const exact = (o, keys, optional = []) => o && typeof o === 'object' && !Array.isArray(o)
  && keys.every(k => k in o) && Object.keys(o).every(k => keys.includes(k) || optional.includes(k));
const number = (v, max) => Number.isInteger(v) && v >= 0 && v <= max;
const kg = v => v === undefined || (typeof v === 'number' && Number.isFinite(v) && v >= 0 && v <= 1000);
const id = v => typeof v === 'string' && /^[a-zA-Z0-9_.-]{1,100}$/.test(v);
export function validSession(v, now = Date.now()) {
  return exact(v, ['version', 'day', 'policy', 'catalog', 'endedEarly', 'plan', 'work'], ['review'])
    && (v.review === undefined || (exact(v.review, ['impression'], ['reason'])
      && ['fits','mixed','notFit'].includes(v.review.impression)
      && (v.review.reason === undefined || ['tooEasy','tooHard','repetitive','unclear'].includes(v.review.reason))))
    && v.version === 1 && /^\d{4}-\d{2}-\d{2}$/.test(v.day) && Number.isFinite(Date.parse(v.day))
    && new Date(v.day).toISOString().slice(0,10) === v.day
    && Date.parse(v.day) <= now && Date.parse(v.day) >= now - 90 * 86400000
    && id(v.policy) && id(v.catalog) && typeof v.endedEarly === 'boolean'
    && Array.isArray(v.plan) && v.plan.length <= 64 && v.plan.every(p =>
      exact(p, ['exercise','sets','target','unit','rest'], ['kg']) && id(p.exercise)
      && number(p.sets, 30) && number(p.target, 3600) && id(p.unit) && number(p.rest, 7200) && kg(p.kg))
    && Array.isArray(v.work) && v.work.length <= 256 && v.work.every(w =>
      exact(w, ['exercise','actual'], ['target','kg','rest','unit']) && id(w.exercise) && number(w.actual, 3600)
      && (w.unit === undefined || id(w.unit))
      && (w.target === undefined || number(w.target, 3600)) && kg(w.kg)
      && (w.rest === undefined || number(w.rest, 86400)));
}

export function collector(file, { maxParticipants = 10000, now = () => Date.now(), backupFile } = {}) {
  if (backupFile && (resolve(backupFile) === resolve(file) || dirname(resolve(backupFile)) !== dirname(resolve(file)))) throw new Error('Backup must be a separate file in the private data directory');
  mkdirSync(dirname(file), { recursive: true, mode: 0o700 });
  const db = new DatabaseSync(file);
  chmodSync(file, 0o600);
  db.exec(`PRAGMA foreign_keys=ON; PRAGMA secure_delete=ON;
    CREATE TABLE IF NOT EXISTS participants(id TEXT PRIMARY KEY, version TEXT, accepted TEXT, revoked INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE IF NOT EXISTS sessions(participant TEXT NOT NULL REFERENCES participants(id), id TEXT NOT NULL, day TEXT NOT NULL, report TEXT NOT NULL, PRIMARY KEY(participant,id));`);
  const discardBackup = () => {
    if (backupFile) { rmSync(backupFile, {force:true}); rmSync(backupFile + '.tmp', {force:true}); }
  };
  const purge = () => {
    const result = db.prepare('DELETE FROM sessions WHERE day <= ?').run(new Date(now()-90*86400000).toISOString().slice(0,10));
    if (result.changes) discardBackup();
  };
  // Single rolling copy. Synchronous SQLite snapshot cannot race a DELETE handler.
  const backup = () => {
    if (!backupFile) return;
    if (existsSync(backupFile) && now()-statSync(backupFile).mtimeMs < 23*3600000) return;
    const temporary = backupFile + '.tmp';
    rmSync(temporary, {force:true});
    db.exec("VACUUM INTO '" + temporary.replaceAll("'", "''") + "'");
    chmodSync(temporary, 0o600); renameSync(temporary, backupFile);
  };
  purge();
  backup();
  const cleanup = setInterval(() => { purge(); backup(); }, 3600000); cleanup.unref();
  let minute = 0, requests = 0;
  const server = createServer(async (req, res) => {
    const reply = (status, error) => { res.writeHead(status, {'Content-Type':'application/json', 'Cache-Control':'no-store', 'X-Content-Type-Options':'nosniff'}); res.end(error ? JSON.stringify({error}) : '{}'); };
    // Global bound; no IP addresses retained. Private endpoint is not a browser API.
    const currentMinute = Math.floor(now()/60000);
    if (minute !== currentMinute) { minute = currentMinute; requests = 0; }
    if (++requests > 600) { req.resume(); return reply(429, 'retry_later'); }
    if (req.headers.origin) { req.resume(); return reply(403, 'browser_not_supported'); }
    const token = /^Bearer ([a-f0-9]{64})$/.exec(req.headers.authorization || '')?.[1];
    if (!token) { req.resume(); return reply(401, 'authorization_required'); }
    const participant = hash(token);
    const route = req.url;
    if (!(route === '/v1/consent' || /^\/v1\/sessions\/[a-f0-9]{64}$/.test(route || ''))) { req.resume(); return reply(404, 'not_found'); }
    try {
      if (req.method === 'DELETE' && route === '/v1/consent') {
        if (!db.prepare('SELECT id FROM participants WHERE id=?').get(participant)
          && db.prepare('SELECT COUNT(*) AS n FROM participants').get().n >= maxParticipants) {
          req.resume(); return reply(503, 'capacity');
        }
        // Tombstone also for unknown tokens: a delayed registration must not resurrect consent.
        db.exec('BEGIN IMMEDIATE');
        try {
          db.prepare('INSERT INTO participants(id,revoked) VALUES(?,1) ON CONFLICT(id) DO UPDATE SET revoked=1,version=NULL,accepted=NULL').run(participant);
          db.prepare('DELETE FROM sessions WHERE participant=?').run(participant);
          db.exec('COMMIT');
        } catch (e) { db.exec('ROLLBACK'); throw e; }
        discardBackup(); // Never acknowledge deletion while a snapshot still contains the reports.
        req.resume(); return reply(200);
      }
      if (req.method !== 'PUT') { req.resume(); return reply(405, 'method_not_allowed'); }
      if (!req.headers['content-type']?.startsWith('application/json')) { req.resume(); return reply(415, 'json_required'); }
      let bytes = 0, parts = [];
      for await (const chunk of req) {
        bytes += chunk.length;
        if (bytes > 65536) { reply(413, 'too_large'); req.destroy(); return; }
        parts.push(chunk);
      }
      let body;
      try { body = JSON.parse(Buffer.concat(parts).toString('utf8')); } catch { return reply(400, 'invalid_json'); }
      const user = db.prepare('SELECT * FROM participants WHERE id=?').get(participant);
      if (user?.revoked) return reply(410, 'consent_revoked');
      if (route === '/v1/consent') {
        if (!exact(body, ['version','acceptedAt']) || !['session-sharing-1','session-sharing-2'].includes(body.version)
          || typeof body.acceptedAt !== 'string' || body.acceptedAt.length > 30
          || !Number.isFinite(Date.parse(body.acceptedAt)) || Date.parse(body.acceptedAt) > now()+60000)
          return reply(400, 'invalid_consent');
        if (!user && db.prepare('SELECT COUNT(*) AS n FROM participants').get().n >= maxParticipants) return reply(503,'capacity');
        if (user && (user.version !== body.version || user.accepted !== body.acceptedAt)) return reply(409,'consent_conflict');
        db.prepare('INSERT OR IGNORE INTO participants(id,version,accepted) VALUES(?,?,?)').run(participant, body.version, body.acceptedAt);
        return reply(200);
      }
      if (!user) return reply(403, 'consent_required');
      if (!validSession(body, now()) || body.day < user.accepted.slice(0,10)) return reply(400, 'invalid_session');
      const sessionID = route.split('/').at(-1);
      const encoded = JSON.stringify(body);
      if (body.review !== undefined && user.version !== 'session-sharing-2') return reply(403, 'review_consent_required');
      const prior = db.prepare('SELECT report FROM sessions WHERE participant=? AND id=?').get(participant, sessionID);
      if (prior) {
        const identical = isDeepStrictEqual(JSON.parse(prior.report), body);
        return reply(identical ? 200 : 409, identical ? undefined : 'immutable_session');
      }
      if (db.prepare('SELECT COUNT(*) AS n FROM sessions WHERE participant=?').get(participant).n >= 1000) return reply(429, 'capacity');
      db.prepare('INSERT INTO sessions VALUES(?,?,?,?)').run(participant, sessionID, body.day, encoded);
      return reply(200);
    } catch { reply(500, 'storage_unavailable'); }
  });
  server.requestTimeout = 15000; server.headersTimeout = 10000;
  server.on('close', () => { clearInterval(cleanup); db.close(); });
  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  if (!process.env.LBS_SHARING_DB) throw new Error('Set LBS_SHARING_DB to a private persistent path outside the repository');
  const server = collector(resolve(process.env.LBS_SHARING_DB), {backupFile: process.env.LBS_SHARING_BACKUP});
  server.listen(Number(process.env.PORT || 3041), process.env.LBS_SHARING_HOST || '127.0.0.1');
}
