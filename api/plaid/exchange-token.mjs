// Exchanges a one-time Plaid public token and encrypts the access token before
// writing it through the service-role REST path. It is never returned to the UI.
import crypto from 'node:crypto';
const supabaseUrl=process.env.SUPABASE_URL||'https://wozynsftofkjqwlflosv.supabase.co';
const publishable=process.env.SUPABASE_PUBLISHABLE_KEY||process.env.SUPABASE_ANON_KEY;
const service=process.env.SUPABASE_SERVICE_ROLE_KEY;
const environment=process.env.PLAID_ENV||'sandbox';
const plaidBase=environment==='production'?'https://production.plaid.com':'https://sandbox.plaid.com';
const body=(data,status=200)=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json','cache-control':'no-store'}});
function token(request){return /^Bearer\s+([^\s]+)$/i.exec(request.headers.get('authorization')||'')?.[1]||null;}
function key(){const raw=Buffer.from(process.env.PLAID_TOKEN_ENCRYPTION_KEY||'','base64');if(raw.length!==32)throw Error('key');return raw;}
async function supa(path,options={}){const headers={apikey:options.admin?service:publishable,authorization:`Bearer ${options.admin?service:options.token}`,accept:'application/json','content-type':'application/json',...(options.headers||{})};const r=await fetch(supabaseUrl+path,{...options,headers});return{r,data:await r.json().catch(()=>null)};}
export async function POST(request){
 if(request.method!=='POST')return body({code:'METHOD'},405);const jwt=token(request);if(!jwt)return body({code:'SESSION'},401);
 if(!publishable||!service||!process.env.PLAID_CLIENT_ID||!process.env.PLAID_SECRET||!process.env.PLAID_TOKEN_ENCRYPTION_KEY)return body({code:'BANKING_NOT_CONFIGURED'},503);
 try{
  const me=await supa('/auth/v1/user',{token:jwt});if(!me.r.ok||typeof me.data?.id!=='string')return body({code:'SESSION'},401);
  const members=await supa('/rest/v1/bb_planner_members?'+new URLSearchParams({select:'household_id,member_role',user_id:`eq.${me.data.id}`}),{token:jwt});
  if(!members.r.ok||members.data?.length!==1||members.data[0].member_role!=='adult')return body({code:'PARENT_ONLY'},403);
  const input=await request.json().catch(()=>({}));if(typeof input.public_token!=='string'||input.public_token.length<20||input.public_token.length>512)return body({code:'REQUEST'},400);
  const plaid=await fetch(`${plaidBase}/item/public_token/exchange`,{method:'POST',headers:{'content-type':'application/json','PLAID-CLIENT-ID':process.env.PLAID_CLIENT_ID,'PLAID-SECRET':process.env.PLAID_SECRET},body:JSON.stringify({client_id:process.env.PLAID_CLIENT_ID,secret:process.env.PLAID_SECRET,public_token:input.public_token})});
  const result=await plaid.json().catch(()=>null);if(!plaid.ok||typeof result?.access_token!=='string'||typeof result?.item_id!=='string'){console.warn('Plaid exchange rejected',{status:plaid.status,error_code:result?.error_code||null,error_type:result?.error_type||null});return body({code:'PLAID_UNAVAILABLE',provider_status:plaid.status,provider_code:typeof result?.error_code==='string'?result.error_code:null,provider_type:typeof result?.error_type==='string'?result.error_type:null},502);}
  const nonce=crypto.randomBytes(12),cipher=crypto.createCipheriv('aes-256-gcm',key(),nonce);const encrypted=Buffer.concat([cipher.update(result.access_token,'utf8'),cipher.final()]);
  const row={household_id:members.data[0].household_id,owner_id:me.data.id,item_id:result.item_id,institution_name:typeof input.institution_name==='string'?input.institution_name.slice(0,160):null,access_token_ciphertext:encrypted.toString('base64'),access_token_nonce:nonce.toString('base64'),access_token_tag:cipher.getAuthTag().toString('base64'),status:'active'};
  // Item IDs are the durable Plaid identity. Explicitly target that unique key
  // so retrying a completed Sandbox Link flow remains idempotent.
  const saved=await supa('/rest/v1/bb_plaid_connections?on_conflict=item_id',{method:'POST',admin:true,body:JSON.stringify(row),headers:{Prefer:'resolution=merge-duplicates,return=minimal'}});
  if(!saved.r.ok){
   const detail=typeof saved.data?.code==='string'?saved.data.code:null;
   console.warn('Plaid connection storage rejected',{status:saved.r.status,code:detail});
   return body({code:'STORAGE_UNAVAILABLE',storage_status:saved.r.status,storage_code:detail},503);
  }
  return body({connected:true,item_id:result.item_id});
 }catch(error){console.warn('Plaid exchange failed',{code:error?.message==='key'?'ENCRYPTION_KEY_INVALID':'EXCHANGE_HANDLER'});return body({code:'BANKING_UNAVAILABLE'},503);}
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
