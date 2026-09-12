// Run on the private server through its existing operator access. No public admin route.
import { DatabaseSync } from 'node:sqlite';
if (!process.env.LBS_SHARING_DB) throw new Error('LBS_SHARING_DB required');
const db = new DatabaseSync(process.env.LBS_SHARING_DB, {readOnly:true});
const participant = process.argv[2];
const since = new Date(Date.now()-90*86400000).toISOString().slice(0,10);
const rows = participant
  ? db.prepare('SELECT day, report FROM sessions WHERE participant=? AND day>=? ORDER BY day,id').all(participant, since)
  : db.prepare('SELECT participant, COUNT(*) AS sessions, MIN(day) AS firstDay, MAX(day) AS lastDay FROM sessions WHERE day>=? GROUP BY participant').all(since);
process.stdout.write(JSON.stringify(rows.map(r => r.report ? {...r, report:JSON.parse(r.report)} : r), null, 2)+'\n');
db.close();
