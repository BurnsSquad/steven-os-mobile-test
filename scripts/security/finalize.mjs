// Read-only evidence comparison. This never connects to Supabase or deletes anything.
import {readFileSync,writeFileSync} from 'node:fs';
import {identities,validateSnapshot,digest,canonical,ensure,ref} from './config.mjs';
export function finalize(beforeRaw,afterRaw,report,ids){
 const before=validateSnapshot(beforeRaw,ids),after=validateSnapshot(afterRaw,ids);
 ensure(report.execution_transport==='REAL_NETWORK_REQUESTS','Offline simulation cannot finalize live evidence');
 const updateOnly=report.mode==='update',caseCount=updateOnly?27:38;
 ensure(report.project_ref===ref&&['update','live'].includes(report.mode)&&report.status===(updateOnly?'UPDATE_CLIENT_CHECKS_PASSED_ADMIN_VERIFICATION_PENDING':'CLIENT_CHECKS_PASSED_ADMIN_VERIFICATION_PENDING'),'Client run incomplete');
 ensure(report.before_digest===digest(before),'Before snapshot does not match client run');
 ensure(Array.isArray(report.cases)&&report.cases.length===caseCount&&report.cases.every(x=>x.result==='PASS'),'Client cases incomplete');
 ensure(new Set(report.cases.map(c=>[c.name,c.actor,c.fixture_id||'',c.table||''].join('|'))).size===caseCount,'Duplicate client case evidence');
 for(const name of (updateOnly?['title UPDATE','completed UPDATE']:['title UPDATE','completed UPDATE','existing own shared DELETE denied'])) for(const actor of ['A','B']) ensure(report.cases.some(c=>c.name===name&&c.actor===actor),'Required case absent');
 for(const actor of ['A','B']) for(const name of ['own membership only','own private baseline only','shared household inventory','creator column denied','household column denied','existing unrelated household UPDATE filtered','restore own disposable fixture','shared baseline preserved','final visible shared baseline and fixtures preserved','final own private baseline preserved']) ensure(report.cases.some(c=>c.name===name&&c.actor===actor),'Required baseline/update case absent');
 for(const actor of ['A','B','C']) ensure(report.cases.some(c=>c.name==='ordinary authentication'&&c.actor===actor),'Authentication case absent');
 if(!updateOnly){
 for(const table of ['bb_test_private_tasks','bb_test_household_members','bb_test_shared_tasks']) ensure(report.cases.some(c=>c.name==='unrelated account unfiltered SELECT empty'&&c.actor==='C'&&c.table===table),'C SELECT inventory absent');
 for(const row of before.shared.filter(r=>r.id.startsWith('bba60000-'))) ensure(report.cases.some(c=>c.name==='unrelated existing-row UPDATE filtered'&&c.actor==='C'&&c.fixture_id===row.id),'C UPDATE target absent');
 for(const name of ['unrelated INSERT denied','unrelated existing-row DELETE denied','unrelated account ID-filtered SELECT empty']) ensure(report.cases.some(c=>c.name===name&&c.actor==='C'),'Required C case absent');
 }
 ensure(Date.parse(before.captured_at)<=Date.parse(report.started_at)&&Date.parse(after.captured_at)>=Date.parse(report.finished_at),'Snapshot chronology mismatch');
 for(const key of ['private','members','shared','auth','metadata','policies','privileges','shared_columns']) ensure(canonical(before[key])===canonical(after[key]),`Before/after ${key} drift`);
 return {status:updateOnly?'UPDATE_CLIENT_AND_ADMIN_SNAPSHOTS_MATCH':'CLIENT_AND_ADMIN_SNAPSHOTS_MATCH',phase:updateOnly?'UPDATE_ONLY':'FULL_CLIENT_SUITE',project_ref:ref,before_digest:digest(before),after_digest:digest(after),client_cases:report.cases.length,verified_at:new Date().toISOString(),provenance:'Operator-attested SQL snapshots; correctness of their actual project source remains an explicit trust boundary',cleanup:'NOT RUN; separate exact-manifest approval required',delete_policy:'Remains denied; no allowed shared DELETE tested',limitations:[...(updateOnly?['DELETE denial and unrelated C isolation NOT RUN in this UPDATE-only phase']:[]),'No production verification or migration','No peer-edit behavior test','No UI desktop/mobile smoke test','No token-expiry/concurrency stress test','No private write regression suite','No shared identity columns other than creator/household attacked','No forensic detection of transient concurrent edits between snapshots']};
}
if(import.meta.url===new URL(process.argv[1]||'', 'file:').href) try{
 const [beforePath,afterPath,reportPath,out]=process.argv.slice(2);
 ensure(out,'Use finalize.mjs <before.json> <after.json> <client-report.json> <new-final-report.json>');
 const read=p=>JSON.parse(readFileSync(p,'utf8'));
 const result=finalize(read(beforePath),read(afterPath),read(reportPath),identities());
 writeFileSync(out,JSON.stringify(result,null,2)+'\n',{flag:'wx',mode:0o600});console.log(result.status);
}catch(e){console.error('Final evidence NOT VERIFIED. Check input format, chronology, exact case inventory, baseline and metadata drift; raw errors omitted.');process.exitCode=1;}
