// Cursor-based Plaid transaction sync. Parent-only; provider payloads are
// reduced to reviewed fields before storage and never returned wholesale.
import crypto from 'node:crypto';
const url=process.env.SUPABASE_URL||'https://wozynsftofkjqwlflosv.supabase.co',pub=process.env.SUPABASE_PUBLISHABLE_KEY||process.env.SUPABASE_ANON_KEY,service=process.env.SUPABASE_SERVICE_ROLE_KEY,env=process.env.PLAID_ENV||'sandbox';
const plaid=env==='production'?'https://production.plaid.com':'https://sandbox.plaid.com';
const reply=(v,s=200)=>new Response(JSON.stringify(v),{status:s,headers:{'content-type':'application/json','cache-control':'no-store'}});
const jwt=r=>/^Bearer\s+([^\s]+)$/i.exec(r.headers.get('authorization')||'')?.[1]||null;
const decrypt=(row)=>{const key=Buffer.from(process.env.PLAID_TOKEN_ENCRYPTION_KEY||'','base64');if(key.length!==32)throw Error('key');const d=crypto.createDecipheriv('aes-256-gcm',key,Buffer.from(row.access_token_nonce,'base64'));d.setAuthTag(Buffer.from(row.access_token_tag,'base64'));return Buffer.concat([d.update(Buffer.from(row.access_token_ciphertext,'base64')),d.final()]).toString('utf8');};
async function supa(path,opt={}){const admin=!!opt.admin;const key=admin?service:pub;const headers={apikey:key,...(admin&&service?.startsWith('sb_secret_')?{}:{authorization:`Bearer ${admin?service:opt.token}`}),accept:'application/json','content-type':'application/json',...(opt.headers||{})};const r=await fetch(url+path,{method:opt.method||'GET',headers,body:opt.body===undefined?undefined:JSON.stringify(opt.body)});return{r,data:await r.json().catch(()=>null)};}
function clean(row,connection,member){const cents=Math.round(Number(row.amount)*100);if(!row.transaction_id||!row.account_id||typeof row.name!=='string'||!Number.isSafeInteger(cents)||!Number.isSafeInteger(Date.parse(row.date||'')))return null;return{connection_id:connection.id,household_id:member.household_id,owner_id:member.user_id,transaction_id:row.transaction_id,account_id:row.account_id,merchant_name:typeof row.merchant_name==='string'?row.merchant_name.slice(0,240):null,name:row.name.slice(0,240),amount_cents:cents,currency_code:typeof row.iso_currency_code==='string'?row.iso_currency_code:null,posted_on:row.date,pending:!!row.pending,category:Array.isArray(row.category)?String(row.category[0]||'').slice(0,120):null,is_removed:false};}
export async function POST(request){
 if(request.method!=='POST')return reply({code:'METHOD'},405);const access=jwt(request);if(!access)return reply({code:'SESSION'},401);
 if(!pub||!service||!process.env.PLAID_CLIENT_ID||!process.env.PLAID_SECRET||!process.env.PLAID_TOKEN_ENCRYPTION_KEY)return reply({code:'BANKING_NOT_CONFIGURED'},503);
 try{
  const me=await supa('/auth/v1/user',{token:access});if(!me.r.ok||typeof me.data?.id!=='string')return reply({code:'SESSION'},401);
  const members=await supa('/rest/v1/bb_planner_members?'+new URLSearchParams({select:'household_id,user_id,member_role',user_id:`eq.${me.data.id}`}),{token:access});const member=members.data?.[0];if(!members.r.ok||members.data?.length!==1||member.member_role!=='adult')return reply({code:'PARENT_ONLY'},403);
  const connections=await supa('/rest/v1/bb_plaid_connections?'+new URLSearchParams({select:'*',household_id:`eq.${member.household_id}`,owner_id:`eq.${me.data.id}`,status:'eq.active',limit:'1'}),{admin:true});const connection=connections.data?.[0];if(!connections.r.ok||!connection)return reply({code:'NO_BANK_CONNECTION'},404);
  const response=await fetch(`${plaid}/transactions/sync`,{method:'POST',headers:{'content-type':'application/json','PLAID-CLIENT-ID':process.env.PLAID_CLIENT_ID,'PLAID-SECRET':process.env.PLAID_SECRET},body:JSON.stringify({client_id:process.env.PLAID_CLIENT_ID,secret:process.env.PLAID_SECRET,access_token:decrypt(connection),cursor:connection.cursor||undefined,count:500})});const result=await response.json().catch(()=>null);if(!response.ok){console.warn('Plaid sync rejected',{status:response.status,error_code:result?.error_code||null,error_type:result?.error_type||null});return reply({code:'PLAID_UNAVAILABLE',provider_status:response.status,provider_code:typeof result?.error_code==='string'?result.error_code:null,provider_type:typeof result?.error_type==='string'?result.error_type:null},502);}
  const rows=[...(result.added||[]),...(result.modified||[])].map(row=>clean(row,connection,member)).filter(Boolean).map(row=>({...row,is_removed:(result.modified||[]).some(x=>x.transaction_id===row.transaction_id&&x.pending===false&&x.amount===0)}));
  if(rows.length){const saved=await supa('/rest/v1/bb_plaid_transactions',{method:'POST',admin:true,headers:{Prefer:'resolution=merge-duplicates,return=minimal'},body:rows});if(!saved.r.ok)return reply({code:'STORAGE_UNAVAILABLE'},503);}
  if(Array.isArray(result.removed)&&result.removed.length){const ids=result.removed.map(x=>x.transaction_id).filter(Boolean);await supa('/rest/v1/bb_plaid_transactions?'+new URLSearchParams({connection_id:`eq.${connection.id}`,transaction_id:`in.(${ids.join(',')})`}),{method:'PATCH',admin:true,headers:{Prefer:'return=minimal'},body:{is_removed:true}});}
  const updated=await supa('/rest/v1/bb_plaid_connections?'+new URLSearchParams({id:`eq.${connection.id}`}),{method:'PATCH',admin:true,headers:{Prefer:'return=minimal'},body:{cursor:result.next_cursor||connection.cursor||null,last_synced_at:new Date().toISOString(),updated_at:new Date().toISOString()}});if(!updated.r.ok)return reply({code:'STORAGE_UNAVAILABLE'},503);
  return reply({synced:true,added:(result.added||[]).length,modified:(result.modified||[]).length,removed:(result.removed||[]).length,has_more:!!result.has_more});
 }catch{return reply({code:'BANKING_UNAVAILABLE'},503);}
}


// Vercel's Node runtime invokes API files through the default (req, res) handler.
// Keep the Web Request implementation above for tests, and adapt it at the boundary.
function toWebRequest(req){
 const headers=new Headers();
 for(const [name,value] of Object.entries(req.headers||{})){ if(value!==undefined) headers.set(name,Array.isArray(value)?value.join(','):String(value)); }
 const init={method:req.method||'GET',headers};
 if(!['GET','HEAD'].includes(init.method)) { init.body=req; init.duplex='half'; }
 return new Request(`https://${req.headers?.host||'localhost'}${req.url||'/'}`,init);
}
async function sendNodeResponse(res,response){
 res.statusCode=response.status; response.headers.forEach((value,name)=>res.setHeader(name,value)); res.end(await response.text());
}
export default async function handler(req,res){
 try { await sendNodeResponse(res,await (req.method==='OPTIONS'?OPTIONS():POST(toWebRequest(req)))); }
 catch { if(!res.headersSent){res.statusCode=503;res.setHeader('content-type','application/json');res.end(JSON.stringify({code:'BANKING_UNAVAILABLE'}));} }
}
