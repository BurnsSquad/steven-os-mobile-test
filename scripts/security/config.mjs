// All live destinations and fictional labels are fixed; credentials never enter source.
import {createHash} from 'node:crypto';
export const ref='wozynsftofkjqwlflosv';
export const origin=`https://${ref}.supabase.co`;
export const household='bba20000-0000-4000-8000-000000000001';
export const foreignHousehold='bba20000-0000-4000-8000-000000000099';
export const tables=['bb_test_private_tasks','bb_test_household_members','bb_test_shared_tasks'];
export const emails={A:'burns-security-a@example.test',B:'burns-security-b@example.test',C:'burns-security-c@example.test'};
export const operations=['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'];
export const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function ensure(ok,message){if(!ok) throw Error(message);}
export function identities(env=process.env){
 const result=Object.fromEntries(['A','B','C'].map(actor=>{const id=env[`BB_TEST_${actor}_ID`];ensure(uuid.test(id||''),`Missing/invalid protected test ${actor} ID`);return [actor,id.toLowerCase()];}));
 ensure(new Set(Object.values(result)).size===3,'Test identities must be distinct');return result;
}
export function configuration(env=process.env){
 ensure(env.BB_TEST_URL===origin,'BB_TEST_URL must exactly match the allowlisted sandbox');
 const key=env.BB_TEST_PUBLISHABLE_KEY;
 ensure(typeof key==='string'&&key.startsWith('sb_publishable_'),'A modern public publishable key is required; no privileged key in the runner');
 return {url:origin,key,ids:identities(env)};
}
export function fixtures(ids){return {
 private:[
  {id:'bba10000-0000-4000-8000-000000000001',owner_id:ids.A,title:'TEST ONLY - Organize fictional workspace',completed:false},
  {id:'bba10000-0000-4000-8000-000000000002',owner_id:ids.B,title:'TEST ONLY - Plan fictional family activity',completed:false}
 ],
 members:[{household_id:household,user_id:ids.A,role:'owner'},{household_id:household,user_id:ids.B,role:'member'}],
 shared:[
  {id:'bba30000-0000-4000-8000-000000000001',household_id:household,created_by:ids.A,title:'TEST ONLY - Organize fictional family game night',completed:false},
  {id:'bba60000-0000-4000-8000-000000000001',household_id:household,created_by:ids.A,title:'TEST ONLY - A fictional shared UPDATE check',completed:false},
  {id:'bba60000-0000-4000-8000-000000000002',household_id:household,created_by:ids.B,title:'TEST ONLY - B fictional shared UPDATE check',completed:false},
  {id:'bba60000-0000-4000-8000-000000000099',household_id:foreignHousehold,created_by:ids.A,title:'TEST ONLY - Unrelated household UPDATE target',completed:false}
 ]};}
export const insertDeniedId='bba70000-0000-4000-8000-000000000003';
export function canonical(value){
 if(Array.isArray(value)) return '['+value.map(canonical).sort().join(',')+']';
 if(value&&typeof value==='object') return '{'+Object.keys(value).sort().map(k=>JSON.stringify(k)+':'+canonical(value[k])).join(',')+'}';
 return JSON.stringify(value);
}
export const digest=value=>createHash('sha256').update(canonical(value)).digest('hex');
export function snapshotValue(raw){
 if(Array.isArray(raw)){ensure(raw.length===1,'Snapshot export must contain one row');raw=raw[0];}
 if(raw?.snapshot) raw=typeof raw.snapshot==='string'?JSON.parse(raw.snapshot):raw.snapshot;
 return raw;
}
export function validateSnapshot(raw,ids,{fresh=false}={}){
 const s=snapshotValue(raw), expected=fixtures(ids);
 ensure(s?.project_ref===ref&&s.execution_role==='postgres','Snapshot identity/role mismatch');
 const age=Date.now()-Date.parse(s.captured_at);
 ensure(Number.isFinite(age)&&age>=-60000&&(!fresh||age<10*60*1000),'Snapshot timestamp invalid or older than ten minutes');
 ensure(s.auth_count===3&&s.public_table_count===3&&s.private_count===2&&s.member_count===2&&s.shared_count===4,'Unexpected user/table/row counts');
 for(const key of ['private','members','shared']){
  ensure(Array.isArray(s[key])&&s[key].length===expected[key].length,`Unexpected ${key} fixture count`);
  for(const item of expected[key]){
   const row=s[key].find(r=>key==='members'?r.user_id===item.user_id&&r.household_id===item.household_id:r.id===item.id);
   ensure(row&&Object.entries(item).every(([k,v])=>row[k]===v),`Unexpected ${key} fixture values`);
   ensure(Number.isFinite(Date.parse(row.created_at)),`Missing ${key} creation timestamp`);
   ensure(Object.keys(row).length===Object.keys(item).length+1,`Unexpected ${key} columns`);
  }
 }
 ensure(canonical(s.auth)===canonical(Object.entries(ids).map(([actor,id])=>({id,email:emails[actor]}))),'Auth identity inventory differs');
 ensure(Array.isArray(s.metadata)&&s.metadata.length===3,'Metadata inventory differs');
 for(const table of tables){
  const m=s.metadata.find(x=>x.table===table);
  ensure(m?.rls===true&&m.owner==='postgres','RLS/owner differs');
 }
 ensure(Array.isArray(s.privileges)&&s.privileges.length===48,'Privilege inventory incomplete');
 for(const table of tables) for(const actor of ['anon','authenticated']) for(const op of operations){
  const p=s.privileges.filter(x=>x.table===table&&x.actor===actor&&x.operation===op);
  const allowed=actor==='authenticated'&&(table===tables[0]?['SELECT','INSERT','UPDATE','DELETE'].includes(op):table===tables[1]?op==='SELECT':['SELECT','INSERT'].includes(op));
  ensure(p.length===1&&p[0].allowed===allowed,'Effective table privileges differ');
 }
 const columns={id:false,household_id:false,created_by:false,title:true,completed:true,created_at:false};
 ensure(Array.isArray(s.shared_columns)&&s.shared_columns.length===12,'Column inventory incomplete');
 for(const actor of ['anon','authenticated']) for(const [column,allowed] of Object.entries(columns)){
  const rows=s.shared_columns.filter(p=>p.actor===actor&&p.column===column);
  ensure(rows.length===1&&rows[0].allowed===(actor==='authenticated'&&allowed),'Effective shared column UPDATE differs');
 }
 ensure(Array.isArray(s.policies)&&s.policies.length===8,'Policy inventory differs');
 const names=['private_select','private_insert','private_update','private_delete','member_select','shared_select','shared_insert','shared_update'];
 for(const name of names){
  const matches=s.policies.filter(p=>p.policyname===name);
  const table=name.startsWith('private_')?tables[0]:name.startsWith('member_')?tables[1]:tables[2];
  const command=name.split('_')[1].toUpperCase();
  ensure(matches.length===1&&matches[0].tablename===table&&matches[0].schemaname==='public'&&matches[0].cmd===command&&matches[0].permissive==='PERMISSIVE'&&canonical(matches[0].roles)===canonical(['authenticated']),'Policy identity/roles/command differs');
 }
 // Policy expressions are recorded and compared before/after; source review remains required.
 return s;
}
export function permissionDenied(r){return r.status===403&&r.body?.code==='42501';}
export function checkNoRedirect(response){ensure(!response.redirected,'Redirect refused');return response;}
export async function request(path,{key,token,method='GET',body,fetcher=fetch}={}){
 ensure(path.startsWith('/auth/v1/')||path.startsWith('/rest/v1/'),'Unexpected API path');
 const response=checkNoRedirect(await fetcher(origin+path,{method,redirect:'error',signal:AbortSignal.timeout(20000),headers:{apikey:key,Authorization:`Bearer ${token||key}`,Accept:'application/json',...(body===undefined?{}:{'Content-Type':'application/json',Prefer:'return=representation'})},...(body===undefined?{}:{body:JSON.stringify(body)})}));
 return {status:response.status,body:await response.json().catch(()=>null)};
}
