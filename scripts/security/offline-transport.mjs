// Synthetic HTTP double for runner guard tests; NEVER a Supabase/RLS implementation.
import {ensure,identities,fixtures,emails,origin,household,canonical} from './config.mjs';
ensure(process.env.BB_TEST_OFFLINE_SIMULATION==='1','Offline transport requires explicit simulation mode');
const ids=identities(),f=fixtures(ids);
const all=Object.fromEntries(Object.entries(f).map(([k,rows])=>[k,rows.map(r=>({...r,created_at:'2026-01-01T00:00:00+00:00'}))]));
const response=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json'}});
const matches=(row,url)=>[...url.searchParams].filter(([k])=>k!=='select').every(([key,value])=>value.startsWith('eq.')&&String(row[key])===value.slice(3));
globalThis.fetch=async (raw,opts)=>{
 const url=new URL(raw);ensure(url.origin===origin,'Simulation refused external host');
 const body=opts.body?JSON.parse(opts.body):null;
 if(url.pathname==='/auth/v1/token'){
  const actor=Object.keys(emails).find(a=>emails[a]===body.email);
  return response({access_token:`OFFLINE_${actor}`,user:{id:ids[actor]}});
 }
 const actor=Object.keys(ids).find(a=>opts.headers.Authorization===`Bearer OFFLINE_${a}`);
 ensure(actor,'Simulation requires an ordinary actor token');
 if(url.pathname==='/auth/v1/user')return response({id:ids[actor],email:emails[actor]});
 const key=url.pathname.endsWith('bb_test_private_tasks')?'private':url.pathname.endsWith('bb_test_household_members')?'members':'shared';
 const visible=all[key].filter(row=>key==='private'?row.owner_id===ids[actor]:key==='members'?row.user_id===ids[actor]:actor!=='C'&&row.household_id===household);
 if(opts.method==='GET')return response(visible.filter(row=>matches(row,url)));
 if(opts.method==='DELETE')return response({code:'42501'},403);
 if(opts.method==='POST')return response({code:'42501'},403);
 if(opts.method==='PATCH'){
  if(Object.keys(body).some(k=>!['title','completed'].includes(k))){
   if(process.env.BB_TEST_OFFLINE_FAULT==='expired-session')return response({code:'42501'},401);
   return response({code:'42501'},403);
  }
  let rows=visible.filter(row=>matches(row,url));
  if(process.env.BB_TEST_OFFLINE_FAULT==='broken-isolation'&&rows.length===0)rows=all.shared.filter(row=>matches(row,url));
  for(const row of rows)Object.assign(row,body);
  return response(rows);
 }
 throw Error('Unsupported simulation request');
};
