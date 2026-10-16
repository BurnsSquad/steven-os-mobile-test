// OFFLINE guard tests only. Synthetic fixtures are not evidence of Supabase enforcement.
import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {configuration,identities,fixtures,origin,ref,emails,operations,tables,validateSnapshot,permissionDenied,canonical,digest,request} from './config.mjs';
import {setupSQL,snapshotSQL,cleanupSQL} from './prepare-sql.mjs';
import {finalize} from './finalize.mjs';
const ids={A:'11111111-1111-4111-8111-111111111111',B:'22222222-2222-4222-8222-222222222222',C:'33333333-3333-4333-8333-333333333333'};
const env={BB_TEST_URL:origin,BB_TEST_PUBLISHABLE_KEY:'sb_publishable_OFFLINE_TEST',...Object.fromEntries(Object.entries(ids).map(([a,id])=>[`BB_TEST_${a}_ID`,id]))};
function synthetic(){const f=fixtures(ids);return {
 project_ref:ref,execution_role:'postgres',captured_at:new Date().toISOString(),auth_count:3,public_table_count:3,private_count:2,member_count:2,shared_count:4,
 auth:Object.entries(ids).map(([a,id])=>({id,email:emails[a]})),
 ...Object.fromEntries(Object.entries(f).map(([key,rows])=>[key,rows.map(r=>({...r,created_at:'2026-01-01T00:00:00+00:00'}))])),
 metadata:tables.map(table=>({table,rls:true,owner:'postgres'})),
 policies:['private_select','private_insert','private_update','private_delete','member_select','shared_select','shared_insert','shared_update'].map(policyname=>({policyname,qual:'OFFLINE_SYNTHETIC',schemaname:'public',tablename:policyname.startsWith('private_')?tables[0]:policyname.startsWith('member_')?tables[1]:tables[2],roles:['authenticated'],cmd:policyname.split('_')[1].toUpperCase(),permissive:'PERMISSIVE'})),
 privileges:tables.flatMap(table=>['anon','authenticated'].flatMap(actor=>operations.map(operation=>({table,actor,operation,allowed:actor==='authenticated'&&(table===tables[0]?['SELECT','INSERT','UPDATE','DELETE'].includes(operation):table===tables[1]?operation==='SELECT':['SELECT','INSERT'].includes(operation))})))),
 shared_columns:['anon','authenticated'].flatMap(actor=>['id','household_id','created_by','title','completed','created_at'].map(column=>({actor,column,allowed:actor==='authenticated'&&['title','completed'].includes(column)})))
 };}
test('Only exact sandbox and a publishable key may be used',()=>{
 assert.equal(configuration(env).url,origin);
 for(const url of ['https://production.supabase.co',origin+'/',origin+'@evil.example',origin.replace('https:','http:')]) assert.throws(()=>configuration({...env,BB_TEST_URL:url}));
 for(const key of ['sb_secret_NEVER','eyJprivileged','']) assert.throws(()=>configuration({...env,BB_TEST_PUBLISHABLE_KEY:key}));
 assert.throws(()=>identities({...env,BB_TEST_C_ID:ids.A}));
});
test('Permission denial never accepts HTTP 401 or unrelated 403 errors',()=>{
 assert.equal(permissionDenied({status:403,body:{code:'42501'}}),true);
 for(const r of [{status:401,body:{code:'42501'}},{status:403,body:{code:'23503'}},{status:403,body:null},{status:200,body:[]}]) assert.equal(permissionDenied(r),false);
});
test('Snapshot rejects missing targets, unexpected grants and baseline drift',()=>{
 const good=synthetic();assert.equal(validateSnapshot(good,ids).shared.length,4);
 const mutations=[s=>s.shared.pop(),s=>s.auth_count=4,s=>s.shared[0].title='changed',s=>s.members.push({...s.members[0],user_id:ids.C}),s=>s.privileges.find(p=>p.actor==='anon').allowed=true,s=>s.shared_columns.find(p=>p.column==='created_by').allowed=true,s=>s.metadata[0].rls=false,s=>s.policies.pop(),s=>s.captured_at='bad',s=>s.project_ref='other'];
 for(const mutate of mutations){const s=structuredClone(good);mutate(s);assert.throws(()=>validateSnapshot(s,ids));}
 const stale=structuredClone(good);stale.captured_at=new Date(Date.now()-11*60*1000).toISOString();assert.throws(()=>validateSnapshot(stale,ids,{fresh:true}));
});
test('Network helper pins origin and refuses redirects',async()=>{
 let observed;
 const result=await request('/rest/v1/bb_test_shared_tasks',{key:'public',token:'REDACTED',fetcher:async(url,opts)=>{observed={url,opts};return {redirected:false,status:403,json:async()=>({code:'42501'})};}});
 assert.equal(result.status,403);assert.equal(observed.url,origin+'/rest/v1/bb_test_shared_tasks');assert.equal(observed.opts.redirect,'error');
 await assert.rejects(request('https://other.example',{key:'public',fetcher:()=>{throw Error('must not call');}}));
 await assert.rejects(request('/auth/v1/user',{key:'public',fetcher:async()=>({redirected:true})}));
});
test('CLI defaults refuse missing configuration before network/write work; secrets are not printed',()=>{
 for(const file of ['run.mjs','provision-auth.mjs']){
  const r=spawnSync(process.execPath,[`scripts/security/${file}`],{cwd:process.cwd(),env:{BB_TEST_ADMIN_KEY:'DO_NOT_PRINT_SECRET',BB_TEST_A_PASSWORD:'DO_NOT_PRINT_PASSWORD'},encoding:'utf8'});
  assert.equal(r.status,1);assert.doesNotMatch(r.stdout+r.stderr,/DO_NOT_PRINT_SECRET|DO_NOT_PRINT_PASSWORD/);
 }
});
test('Setup proposal has no destructive deletion/default privilege changes; snapshot is a SELECT',()=>{
 const sql=setupSQL(ids);
 assert.match(sql,/BEGIN;/);assert.match(sql,/COMMIT;/);assert.match(sql,/CREATE POLICY shared_update/);
 assert.doesNotMatch(sql,/\b(?:DROP|TRUNCATE|ALTER DEFAULT PRIVILEGES)\s/i);
 assert.doesNotMatch(sql,/CREATE POLICY\s+\w+\s+ON public\.bb_test_shared_tasks FOR DELETE/i);
 assert.equal(snapshotSQL(ids).startsWith('SELECT '),true);
});
test('Cleanup requires finalized matching evidence and excludes protected baseline IDs from DELETE',()=>{
 const s=synthetic();assert.throws(()=>cleanupSQL(s,ids));
 const sql=cleanupSQL(s,ids,{status:'CLIENT_AND_ADMIN_SNAPSHOTS_MATCH',project_ref:ref,after_digest:digest(s)});
 const deletes=sql.split('\n').filter(l=>l.startsWith('DELETE FROM'));
 assert.equal(deletes.length,3);
 for(const line of deletes){assert.match(line,/bba60000-/);assert.match(line,/household_id=/);assert.match(line,/created_by=/);assert.match(line,/created_at=/);assert.match(line,/RETURNING/);assert.doesNotMatch(line,/bba10000-|bba30000-/);}
 assert.doesNotMatch(sql,/\bCASCADE\b|DELETE FROM auth\.|DELETE FROM public\.bb_test_household_members/i);
});
test('Finalization rejects incomplete or drifted evidence',()=>{
 const before=synthetic();before.captured_at='2026-10-16T14:00:00Z';
 const after=structuredClone(before);after.captured_at='2026-10-16T14:03:00Z';
 const cases=[];
 for(const name of ['title UPDATE','completed UPDATE','existing own shared DELETE denied']) for(const actor of ['A','B'])cases.push({name,actor,result:'PASS'});
 for(const name of ['unrelated INSERT denied','unrelated existing-row DELETE denied','unrelated account ID-filtered SELECT empty']) cases.push({name,actor:'C',result:'PASS'});
 while(cases.length<35)cases.push({name:'OFFLINE_SYNTHETIC_ONLY',actor:'A',result:'PASS'});
 const report={project_ref:ref,mode:'live',status:'CLIENT_CHECKS_PASSED_ADMIN_VERIFICATION_PENDING',before_digest:digest(before),started_at:'2026-10-16T14:01:00Z',finished_at:'2026-10-16T14:02:00Z',cases};
 assert.throws(()=>finalize(before,after,report,ids));
 const drift=structuredClone(after);drift.policies[0].qual='changed';assert.throws(()=>finalize(before,drift,report,ids));
 assert.throws(()=>finalize(before,after,{...report,status:'STOPPED_REVIEW_REQUIRED'},ids));
 assert.throws(()=>finalize(before,after,{...report,cases:cases.slice(0,2)},ids));
 assert.notEqual(digest(before),digest(after));assert.equal(canonical([1,2]),canonical([2,1]));
});

test('Full runner simulation restores fixtures, rejects false 401 passes and catches isolation failures',()=>{
 const dir=mkdtempSync(join(tmpdir(),'burns-security-offline-'));
 try{
  const before=synthetic();before.captured_at=new Date(Date.now()-1000).toISOString();
  const path=join(dir,'before.json');writeFileSync(path,JSON.stringify(before));
  for(const fault of ['', 'expired-session', 'broken-isolation']){
   const output=join(dir,(fault||'healthy')+'.json');
   const r=spawnSync(process.execPath,['--import','./scripts/security/offline-transport.mjs','scripts/security/run.mjs','--mode','live','--before',path,'--out',output],{cwd:process.cwd(),encoding:'utf8',env:{...env,BB_TEST_A_PASSWORD:'OFFLINE_ONLY_A_PASSWORD_24_CHARS',BB_TEST_B_PASSWORD:'OFFLINE_ONLY_B_PASSWORD_24_CHARS',BB_TEST_C_PASSWORD:'OFFLINE_ONLY_C_PASSWORD_24_CHARS',BB_TEST_POLICY_REVIEW:ref,BB_TEST_SNAPSHOT_ATTESTATION:ref,BB_TEST_UPDATE_APPROVAL:ref,BB_TEST_DELETE_DENIAL_APPROVAL:ref,BB_TEST_OFFLINE_SIMULATION:'1',BB_TEST_OFFLINE_FAULT:fault}});
   const report=JSON.parse(readFileSync(output,'utf8'));
   assert.equal(report.execution_transport,'OFFLINE_SIMULATION');
   assert.doesNotMatch(readFileSync(output,'utf8'),/OFFLINE_ONLY_.*PASSWORD|OFFLINE_A|OFFLINE_B|OFFLINE_C/);
   if(!fault){
    assert.equal(r.status,0,r.stderr);assert.equal(report.cases.length,38);assert.equal(report.status,'CLIENT_CHECKS_PASSED_ADMIN_VERIFICATION_PENDING');
    const after=structuredClone(before);after.captured_at=new Date().toISOString();
    assert.throws(()=>finalize(before,after,report,ids),/Offline simulation/);
    // Exercise comparator logic with synthetic evidence only; not emitted as live report.
    assert.equal(finalize(before,after,{...report,execution_transport:'REAL_NETWORK_REQUESTS'},ids).cleanup.startsWith('NOT RUN'),true);
   }else{
    assert.equal(r.status,1);assert.equal(report.status,'STOPPED_REVIEW_REQUIRED');
    assert.equal(report.cases.some(c=>c.result==='FAIL'),true);
    assert.equal(report.cases.some(c=>c.name==='restore own disposable fixture'&&c.result==='PASS'),true);
   }
  }
 }finally{rmSync(dir,{recursive:true,force:true});}
});

test('Post-cleanup verifier preserves baselines, memberships, identities and policies',async()=>{
 const {verifyCleanup}=await import('./verify-cleanup.mjs');
 const before=synthetic(),after=structuredClone(before);
 after.shared=after.shared.slice(0,1);after.shared_count=1;
 const finalReport={status:'CLIENT_AND_ADMIN_SNAPSHOTS_MATCH',project_ref:ref,after_digest:digest(before),limitations:['OFFLINE_TEST']};
 assert.equal(verifyCleanup(before,after,finalReport,ids).cleanup_rows,3);
 const wrong=structuredClone(after);wrong.shared[0].completed=true;assert.throws(()=>verifyCleanup(before,wrong,finalReport,ids));
 const members=structuredClone(after);members.members.pop();assert.throws(()=>verifyCleanup(before,members,finalReport,ids));
 const grant=structuredClone(after);grant.privileges[0].allowed=true;assert.throws(()=>verifyCleanup(before,grant,finalReport,ids));
});

test('UPDATE-only simulation needs no DELETE approval and cannot finalize cleanup',()=>{
 const dir=mkdtempSync(join(tmpdir(),'burns-update-offline-'));
 try{
  const before=synthetic();before.captured_at=new Date(Date.now()-1000).toISOString();
  const path=join(dir,'before.json'),output=join(dir,'update.json');writeFileSync(path,JSON.stringify(before));
  const r=spawnSync(process.execPath,['--import','./scripts/security/offline-transport.mjs','scripts/security/run.mjs','--mode','update','--before',path,'--out',output],{cwd:process.cwd(),encoding:'utf8',env:{...env,BB_TEST_A_PASSWORD:'OFFLINE_ONLY_A_PASSWORD_24_CHARS',BB_TEST_B_PASSWORD:'OFFLINE_ONLY_B_PASSWORD_24_CHARS',BB_TEST_C_PASSWORD:'OFFLINE_ONLY_C_PASSWORD_24_CHARS',BB_TEST_POLICY_REVIEW:ref,BB_TEST_SNAPSHOT_ATTESTATION:ref,BB_TEST_UPDATE_APPROVAL:ref,BB_TEST_OFFLINE_SIMULATION:'1'}});
  assert.equal(r.status,0,r.stderr);
  const report=JSON.parse(readFileSync(output,'utf8'));
  assert.equal(report.mode,'update');assert.equal(report.cases.length,27);assert.equal(report.status,'UPDATE_CLIENT_CHECKS_PASSED_ADMIN_VERIFICATION_PENDING');
  assert.equal(report.cases.some(c=>['DELETE','POST'].includes(c.method)),false);
  const after=structuredClone(before);after.captured_at=new Date().toISOString();
  assert.throws(()=>finalize(before,after,report,ids),/Offline simulation/);
  const final=finalize(before,after,{...report,execution_transport:'REAL_NETWORK_REQUESTS'},ids);
  assert.equal(final.status,'UPDATE_CLIENT_AND_ADMIN_SNAPSHOTS_MATCH');
  assert.throws(()=>cleanupSQL(after,ids,final));
 }finally{rmSync(dir,{recursive:true,force:true});}
});

test('Private launcher accepts only pinned session paths and hidden TTY input',async()=>{
 const {PassThrough}=await import('node:stream');
 const {readHidden,validateSessionURL}=await import('./private-run.mjs');
 const good='https://raw.githubusercontent.com/BurnsSquad/steven-os-mobile-test/'+('a'.repeat(40))+'/docs/evidence/sandbox-session.json';
 assert.equal(validateSessionURL(good),good);
 for(const url of [good.replace('raw.githubusercontent.com','evil.example'),good+'?token=bad',good.replace('a'.repeat(40),'main'),good.replace('https:','http:')])assert.throws(()=>validateSessionURL(url));
 const input=new PassThrough(),output=new PassThrough();let transcript='';
 input.isTTY=true;input.isRaw=false;input.setRawMode=raw=>{input.isRaw=raw;};output.isTTY=true;output.on('data',chunk=>transcript+=chunk);
 const p=readHidden('Private test input',input,output);input.write('HIDDEN_SENTINEL\u007fL\r');
 assert.equal(await p,'HIDDEN_SENTINEL');assert.equal(input.isRaw,false);assert.doesNotMatch(transcript,/HIDDEN_SENTINEL/);
 const cancelled=readHidden('Cancel test',input,output);input.write('\u0003');await assert.rejects(cancelled,/Cancelled/);assert.equal(input.isRaw,false);
 await assert.rejects(readHidden('Reject pipe',new PassThrough(),output),/interactive Terminal/);
 input.destroy();output.destroy();
});
