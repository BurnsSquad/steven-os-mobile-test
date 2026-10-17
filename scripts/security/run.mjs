// Ordinary-user API tests only. No admin key is used or accepted in this runner.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {dirname} from 'node:path';
import {configuration,validateSnapshot,digest,canonical,ensure,fixtures,ref,household,emails,insertDeniedId,permissionDenied,request} from './config.mjs';
const arg=key=>{const i=process.argv.indexOf(key);return i<0?null:process.argv[i+1];};
async function main(){
 const cfg=configuration(),mode=arg('--mode')||'preflight';
 ensure(['preflight','update','live'].includes(mode),'Use preflight, update or live');
 ensure(!process.env.BB_TEST_ADMIN_KEY,'Remove privileged admin key from ordinary-user test process');
 ensure(process.env.BB_TEST_POLICY_REVIEW===ref,'Review snapshot policy expressions against generated setup SQL before testing');
 ensure(process.env.BB_TEST_SNAPSHOT_ATTESTATION===ref,'Confirm sandbox snapshot provenance with BB_TEST_SNAPSHOT_ATTESTATION');
 const beforePath=arg('--before'),out=arg('--out');
 ensure(beforePath&&out,'Use --before <snapshot.json> --out <new-report.json>');
 const before=validateSnapshot(JSON.parse(readFileSync(beforePath,'utf8')),cfg.ids,{fresh:true});
 if(mode==='update'||mode==='live') ensure(process.env.BB_TEST_UPDATE_APPROVAL===ref,'Live UPDATE approval guard missing');
 if(mode==='live') ensure(process.env.BB_TEST_DELETE_DENIAL_APPROVAL===ref,'Explicit existing-fixture DELETE-denial approval required');
 // Reserve the artifact before login/writes. Never overwrite previous evidence.
 mkdirSync(dirname(out),{recursive:true});
 writeFileSync(out,JSON.stringify({status:'STARTING',project_ref:ref}),{flag:'wx',mode:0o600});
 const report={schema:1,project_ref:ref,execution_transport:process.env.BB_TEST_OFFLINE_SIMULATION==='1'?'OFFLINE_SIMULATION':'REAL_NETWORK_REQUESTS',mode,started_at:new Date().toISOString(),before_digest:digest(before),snapshot_provenance:'operator-attested SQL export; not independently fetched by this runner',cases:[],status:'RUNNING'};
 const sessions={},f=fixtures(cfg.ids);let activeCase='authentication';
 const persist=()=>writeFileSync(out,JSON.stringify(report,null,2)+'\n',{mode:0o600});
 const record=(name,actor,ok,detail={})=>{report.cases.push({name,actor,result:ok?'PASS':'FAIL',at:new Date().toISOString(),...detail});persist();ensure(ok,`Case failed: ${name} (${actor}); stop and inspect`);};
 const api=async(actor,path,method='GET',body)=>request(path,{key:cfg.key,token:sessions[actor],method,body});
 const validSession=async actor=>{const r=await api(actor,'/auth/v1/user');ensure(r.status===200&&r.body?.id===cfg.ids[actor]&&r.body?.email===emails[actor],`Authentication not verified for ${actor}; result INCONCLUSIVE`);};
 const pathFor=row=>'/rest/v1/bb_test_shared_tasks?select=*&'+new URLSearchParams({id:`eq.${row.id}`,household_id:`eq.${row.household_id}`,created_by:`eq.${row.created_by}`});
 const get=async(actor,row)=>api(actor,pathFor(row));
 const exact=(r,rows)=>r.status===200&&Array.isArray(r.body)&&canonical(r.body)===canonical(rows);
 const patch=async(actor,row,body)=>{
  const query=pathFor(row)+'&'+new URLSearchParams({title:`eq.${row.title}`,completed:`eq.${row.completed}`});
  return api(actor,query,'PATCH',body);
 };
 const errorEvidence=r=>({http:r.status,sqlstate:typeof r.body?.code==='string'?r.body.code:null,returned_rows:Array.isArray(r.body)?r.body.length:null});
 const original=id=>before.shared.find(r=>r.id===id);
 const baseline=original(f.shared[0].id);
 try{
  for(const actor of ['A','B','C']){
   const password=process.env[`BB_TEST_${actor}_PASSWORD`];ensure(typeof password==='string'&&password.length>0,`Protected ${actor} test password missing`);
   const r=await request('/auth/v1/token?grant_type=password',{key:cfg.key,method:'POST',body:{email:emails[actor],password}});
   ensure(r.status===200&&typeof r.body?.access_token==='string'&&r.body?.user?.id===cfg.ids[actor],`Ordinary ${actor} login failed; INCONCLUSIVE`);
   sessions[actor]=r.body.access_token;await validSession(actor);
   record('ordinary authentication',actor,true,{authentication_mode:'password grant, regular authenticated user; token omitted'});
  }
  for(const actor of ['A','B']){
   activeCase='initial baseline reads';
   const members=await api(actor,'/rest/v1/bb_test_household_members?select=*');
   record('own membership only',actor,exact(members,before.members.filter(x=>x.user_id===cfg.ids[actor])));
   const privateRows=await api(actor,'/rest/v1/bb_test_private_tasks?select=*');
   record('own private baseline only',actor,exact(privateRows,before.private.filter(x=>x.owner_id===cfg.ids[actor])));
   const shared=await api(actor,'/rest/v1/bb_test_shared_tasks?select=*');
   record('shared household inventory',actor,exact(shared,before.shared.filter(x=>x.household_id===household)));
  }
  if(mode==='update'||mode==='live'){
   for(const actor of ['A','B']){
    const seed=original(f.shared[actor==='A'?1:2].id);let current=seed;
    activeCase=`UPDATE disposable ${actor}`;
    try{
     await validSession(actor);
     const title=seed.title+' - edited';
     let r=await patch(actor,current,{title});
     current={...seed,title};
     record('title UPDATE',actor,exact(r,[current])&&exact(await get(actor,seed),[current]),{fixture_id:seed.id,method:'PATCH',changed_columns:['title'],...errorEvidence(r)});
     r=await patch(actor,current,{completed:true});current={...current,completed:true};
     record('completed UPDATE',actor,exact(r,[current])&&exact(await get(actor,seed),[current]),{fixture_id:seed.id,method:'PATCH',changed_columns:['completed'],...errorEvidence(r)});
     for(const [name,body] of [
      ['creator column denied',{created_by:cfg.ids[actor==='A'?'B':'A']}],
      ['household column denied',{household_id:f.shared[3].household_id}]
     ]){
      await validSession(actor);r=await patch(actor,current,body);await validSession(actor);
      record(name,actor,permissionDenied(r)&&exact(await get(actor,seed),[current]),{fixture_id:seed.id,method:'PATCH',changed_columns:Object.keys(body),...errorEvidence(r)});
     }
     const foreign=original(f.shared[3].id);
     await validSession(actor);r=await patch(actor,foreign,{title:'TEST ONLY - unauthorized UPDATE must not apply'});await validSession(actor);
     record('existing unrelated household UPDATE filtered',actor,exact(r,[]),{fixture_id:foreign.id,method:'PATCH',...errorEvidence(r),admin_unchanged_evidence:'PENDING post-snapshot comparison'});
    }finally{
     // Restore only our exact known disposable identity and one of our known test states.
     const r=await get(actor,seed);
     const unchanged=exact(r,[seed]);
     if(!unchanged){
      ensure(r.status===200&&Array.isArray(r.body)&&r.body.length===1,'Fixture cannot be inspected for safe restoration; manual review required');
      const now=r.body[0];
      const known=[{...seed,title:seed.title+' - edited'},{...seed,title:seed.title+' - edited',completed:true}];
      ensure(known.some(x=>canonical(x)===canonical(now)),'Unexpected fixture state; do not overwrite it');
      const restored=await patch(actor,now,{title:seed.title,completed:false});
      record('restore own disposable fixture',actor,exact(restored,[seed])&&exact(await get(actor,seed),[seed]),{fixture_id:seed.id,method:'PATCH'});
     } else record('own fixture already restored',actor,true,{fixture_id:seed.id});
    }
    record('shared baseline preserved',actor,exact(await get(actor,baseline),[baseline]));
   }
  }
  if(mode==='live'){
   activeCase='DELETE denial';
   for(const actor of ['A','B']){
    const row=original(f.shared[actor==='A'?1:2].id);
    await validSession(actor);ensure(exact(await get(actor,row),[row]),'DELETE target missing before request');
    const r=await api(actor,pathFor(row)+'&'+new URLSearchParams({title:`eq.${row.title}`,completed:'eq.false'}),'DELETE',undefined);
    await validSession(actor);
    record('existing own shared DELETE denied',actor,permissionDenied(r)&&exact(await get(actor,row),[row]),{fixture_id:row.id,method:'DELETE',...errorEvidence(r),boundary:'table privilege denial, not DELETE RLS proof'});
   }
   activeCase='unrelated C isolation';await validSession('C');
   for(const table of ['bb_test_household_members','bb_test_shared_tasks','bb_test_private_tasks']){
    const r=await api('C',`/rest/v1/${table}?select=*`);
    record('unrelated account unfiltered SELECT empty','C',exact(r,[]),{table,method:'GET',...errorEvidence(r)});
   }
   const visible=original(f.shared[1].id);
   record('unrelated account ID-filtered SELECT empty','C',exact(await get('C',visible),[]),{fixture_id:visible.id,method:'GET'});
   let r=await api('C','/rest/v1/bb_test_shared_tasks?select=*','POST',{id:insertDeniedId,household_id:household,created_by:cfg.ids.C,title:'TEST ONLY - C denied INSERT check',completed:false});
   await validSession('C');
   record('unrelated INSERT denied','C',permissionDenied(r),{fixture_id:insertDeniedId,method:'POST',...errorEvidence(r),admin_absence_evidence:'PENDING post-snapshot comparison'});
   for(const row of before.shared.filter(r=>r.id.startsWith('bba60000-'))){
    await validSession('C');r=await patch('C',row,{title:'TEST ONLY - C unauthorized UPDATE must not apply'});await validSession('C');
    record('unrelated existing-row UPDATE filtered','C',exact(r,[]),{fixture_id:row.id,method:'PATCH',...errorEvidence(r),admin_unchanged_evidence:'PENDING post-snapshot comparison'});
   }
   r=await api('C',pathFor(visible),'DELETE');await validSession('C');
   record('unrelated existing-row DELETE denied','C',permissionDenied(r),{fixture_id:visible.id,method:'DELETE',...errorEvidence(r),boundary:'table privilege denial; admin unchanged evidence pending'});
  }
  activeCase='final client baseline verification';
  for(const actor of ['A','B']){
   const r=await api(actor,'/rest/v1/bb_test_shared_tasks?select=*');
   record('final visible shared baseline and fixtures preserved',actor,exact(r,before.shared.filter(x=>x.household_id===household)));
   const p=await api(actor,'/rest/v1/bb_test_private_tasks?select=*');
   record('final own private baseline preserved',actor,exact(p,before.private.filter(x=>x.owner_id===cfg.ids[actor])));
  }
  report.status=mode==='live'?'CLIENT_CHECKS_PASSED_ADMIN_VERIFICATION_PENDING':mode==='update'?'UPDATE_CLIENT_CHECKS_PASSED_ADMIN_VERIFICATION_PENDING':'PREFLIGHT_PASSED_NO_TEST_WRITES';
 }catch(e){
  report.status='STOPPED_REVIEW_REQUIRED';
  report.cases.push({name:activeCase,result:'INCONCLUSIVE_OR_FAILED',reason:'Stopped. Inspect preceding case and current fixture state; raw exceptions omitted to avoid secret leakage.'});
  process.exitCode=1;
 }finally{
  // Tokens are discarded with this process. No credentials or API response bodies persisted.
  report.finished_at=new Date().toISOString();persist();
  console.log(JSON.stringify({status:report.status,cases:report.cases.length,artifact:out}));
 }
}
main().catch(()=>{console.error('Preflight refused or output unavailable. Check sandbox URL/key/IDs, fresh snapshot, approval guards and unused output path. No live result claimed.');process.exitCode=1;});
