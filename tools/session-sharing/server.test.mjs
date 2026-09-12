import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { collector } from './server.mjs';
import { DatabaseSync } from 'node:sqlite';

test('consent, immutable retries, isolation, privacy allowlist and durable deletion', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'lbs-sharing-'));
  const file = join(dir,'test.sqlite');
  let server = collector(file);
  async function start() { await new Promise(r => server.listen(0,'127.0.0.1',r)); }
  await start();
  const call = (method, path, body, token='a'.repeat(64)) => fetch(`http://127.0.0.1:${server.address().port}/v1/${path}`, {
    method, headers: {'Authorization':`Bearer ${token}`, 'Content-Type':'application/json'}, body: body && JSON.stringify(body)
  }).then(r=>r.status);
  const report = {version:1,day:new Date().toISOString().slice(0,10),policy:'first-sessions-1',catalog:'test',endedEarly:true,
    plan:[{exercise:'squat',sets:2,target:8,unit:'repetitions',rest:90}],work:[{exercise:'squat',actual:6,target:8}]};
  const consent = {version:'session-sharing-1',acceptedAt:new Date().toISOString()};
  const sid = 'sessions/'+'f'.repeat(64);
  try {
    assert.equal(await call('PUT',sid,report),403);
    assert.equal(await call('PUT','consent',consent),200);
    assert.equal(await call('PUT',sid,{...report,pain:5}),400);
    assert.equal(await call('PUT',sid,{...report,work:[{...report.work[0],email:'private'}]}),400);
    assert.equal(await call('PUT',sid,{...report,day:'2026-02-30'}),400);
    assert.equal(await call('PUT',sid,report),200);
    assert.equal(await call('PUT',sid,report),200);
    const reordered = Object.fromEntries(Object.entries(report).reverse());
    reordered.work = report.work.map(w => Object.fromEntries(Object.entries(w).reverse()));
    assert.equal(await call('PUT',sid,reordered),200);
    assert.equal(await call('PUT',sid,{...report,endedEarly:false}),409);
    assert.equal(await call('PUT',sid,report,'b'.repeat(64)),403);
    assert.equal(await call('GET',sid),405);
    assert.equal(await call('DELETE','consent'),200);
    const check = new DatabaseSync(file, {readOnly:true});
    assert.equal(check.prepare('SELECT COUNT(*) AS n FROM sessions').get().n, 0);
    check.close();
    assert.equal(await call('DELETE','consent'),200);
    assert.equal(await call('PUT',sid,report),410);
    assert.equal(await call('PUT','consent',consent),410);
    await new Promise(r => server.close(r)); server = collector(file); await start();
    assert.equal(await call('PUT','consent',consent),410);
    assert.equal(await call('DELETE','consent',undefined,'c'.repeat(64)),200);
    assert.equal(await call('PUT','consent',consent,'c'.repeat(64)),410);
    assert.equal(await call('PUT','consent',consent,'d'.repeat(64)),200);
    assert.equal(await call('PUT',sid,report,'d'.repeat(64)),200);
    await new Promise(r => server.close(r));
    server = collector(file, {now: () => Date.now() + 91*86400000}); await start();
    const retained = new DatabaseSync(file, {readOnly:true});
    assert.equal(retained.prepare('SELECT COUNT(*) AS n FROM sessions').get().n, 0);
    retained.close();
  } finally { await new Promise(r=>server.close(r)); rmSync(dir,{recursive:true}); }
});

test('rolling backup is usable and deleted alongside reports, including an interrupted temporary copy', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'lbs-backup-'));
  const file = join(dir,'sessions.sqlite'), backupFile = join(dir,'backup.sqlite');
  let server = collector(file, {backupFile});
  await new Promise(r => server.listen(0,'127.0.0.1',r));
  const headers = {Authorization:'Bearer '+'e'.repeat(64),'Content-Type':'application/json'};
  const send = (method,path,body) => fetch(`http://127.0.0.1:${server.address().port}/v1/${path}`,{method,headers,body:body&&JSON.stringify(body)}).then(r=>r.status);
  try {
    await send('PUT','consent',{version:'session-sharing-1',acceptedAt:new Date().toISOString()});
    await send('PUT','sessions/'+'a'.repeat(64),{version:1,day:new Date().toISOString().slice(0,10),policy:'test',catalog:'test',endedEarly:true,plan:[],work:[]});
    await new Promise(r => server.close(r));
    // Force next backup due, then verify it can be opened as a SQLite database.
    const {unlinkSync,copyFileSync,existsSync} = await import('node:fs');
    unlinkSync(backupFile);
    server = collector(file, {backupFile}); await new Promise(r => server.listen(0,'127.0.0.1',r));
    const recovered = new DatabaseSync(backupFile,{readOnly:true});
    assert.equal(recovered.prepare('SELECT COUNT(*) AS n FROM sessions').get().n,1); recovered.close();
    copyFileSync(backupFile,backupFile+'.tmp');
    assert.equal(await send('DELETE','consent'),200);
    assert.equal(existsSync(backupFile),false); assert.equal(existsSync(backupFile+'.tmp'),false);
  } finally { await new Promise(r=>server.close(r)); rmSync(dir,{recursive:true}); }
});


test('failed backup renewal preserves the previous readable snapshot', async () => {
  const {mkdirSync,utimesSync} = await import('node:fs');
  const dir=mkdtempSync(join(tmpdir(),'lbs-backup-failure-'));
  const file=join(dir,'sessions.sqlite'), backupFile=join(dir,'backup.sqlite');
  const server=collector(file,{backupFile});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  await new Promise(r=>server.close(r));
  try {
    utimesSync(backupFile,new Date(0),new Date(0));
    mkdirSync(backupFile+'.tmp');
    assert.throws(()=>collector(file,{backupFile}));
    const previous=new DatabaseSync(backupFile,{readOnly:true});
    assert.equal(previous.prepare('PRAGMA integrity_check').get().integrity_check,'ok');
    previous.close();
  } finally { rmSync(dir,{recursive:true}); }
});


test('structured review requires new consent, rejects free text and remains immutable', async () => {
 const dir=mkdtempSync(join(tmpdir(),'lbs-review-'));
 const server=collector(join(dir,'test.sqlite')); await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const call=(method,path,body,token)=>fetch(`http://127.0.0.1:${server.address().port}/v1/${path}`,{method,headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:body&&JSON.stringify(body)}).then(r=>r.status);
 const old='1'.repeat(64),current='2'.repeat(64),path='sessions/'+'3'.repeat(64);
 const report={version:1,day:new Date().toISOString().slice(0,10),policy:'test',catalog:'test',endedEarly:true,plan:[],work:[],review:{impression:'mixed',reason:'repetitive'}};
 try {
  for (const [token,version] of [[old,'session-sharing-1'],[current,'session-sharing-2']]) assert.equal(await call('PUT','consent',{version,acceptedAt:new Date().toISOString()},token),200);
  assert.equal(await call('PUT',path,report,old),403);
  assert.equal(await call('PUT',path,{...report,review:{impression:'mixed',text:'secret'}},current),400);
  assert.equal(await call('PUT',path,report,current),200);
  assert.equal(await call('PUT',path,report,current),200);
  assert.equal(await call('PUT',path,{...report,review:{impression:'fits'}},current),409);
  assert.equal(await call('DELETE','consent',undefined,current),200);
  assert.equal(await call('PUT',path,report,current),410);
 } finally { await new Promise(r=>server.close(r)); rmSync(dir,{recursive:true}); }
});
