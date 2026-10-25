// Creates a short-lived Plaid Link token for an authenticated parent.
// No Plaid secret or access token is returned to the browser.
const supabaseUrl=process.env.SUPABASE_URL||'https://wozynsftofkjqwlflosv.supabase.co';
const supabaseKey=process.env.SUPABASE_PUBLISHABLE_KEY||process.env.SUPABASE_ANON_KEY;
const plaidEnv=process.env.PLAID_ENV||'sandbox';
const plaidBase=plaidEnv==='production'?'https://production.plaid.com':'https://sandbox.plaid.com';
const json=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:{'content-type':'application/json','cache-control':'no-store'}});
const auth=(request)=>/^Bearer\s+([^\s]+)$/i.exec(request.headers.get('authorization')||'')?.[1]||null;
async function call(path,options={}){const response=await fetch(supabaseUrl+path,{...options,headers:{apikey:supabaseKey,authorization:options.token?`Bearer ${options.token}`:undefined,accept:'application/json','content-type':'application/json'}});return {response,data:await response.json().catch(()=>null)};}
export function OPTIONS(){return new Response(null,{status:204,headers:{'access-control-allow-origin':'*','access-control-allow-headers':'authorization,content-type','access-control-allow-methods':'POST,OPTIONS'} });}
export async function POST(request){
 if(request.method!=='POST')return json({code:'METHOD'},405);
 const token=auth(request);if(!token)return json({code:'SESSION'},401);
 if(!supabaseKey||!process.env.PLAID_CLIENT_ID||!process.env.PLAID_SECRET)return json({code:'BANKING_NOT_CONFIGURED'},503);
 try{
  const identity=await call('/auth/v1/user',{token});
  if(!identity.response.ok||typeof identity.data?.id!=='string')return json({code:'SESSION'},401);
  const members=await call('/rest/v1/bb_planner_members?'+new URLSearchParams({select:'household_id,member_role',user_id:`eq.${identity.data.id}`}),{token});
  if(!members.response.ok||members.data?.length!==1||members.data[0].member_role!=='adult')return json({code:'PARENT_ONLY'},403);
  const body=await request.json().catch(()=>({}));
  const clientUserId=`bb-${identity.data.id}`;
  const plaid=await fetch(`${plaidBase}/link/token/create`,{method:'POST',headers:{'content-type':'application/json','PLAID-CLIENT-ID':process.env.PLAID_CLIENT_ID,'PLAID-SECRET':process.env.PLAID_SECRET},body:JSON.stringify({client_name:'Burns Base',language:'en',country_codes:['US'],user:{client_user_id:clientUserId},products:['auth','transactions'],...(typeof body.redirect_uri==='string'&&body.redirect_uri?{redirect_uri:body.redirect_uri}:{})})});
  const result=await plaid.json().catch(()=>null);if(!plaid.ok||typeof result?.link_token!=='string'){console.warn('Plaid link token rejected',{status:plaid.status,error_code:result?.error_code||null,error_type:result?.error_type||null});return json({code:'PLAID_UNAVAILABLE',provider_status:plaid.status,provider_code:typeof result?.error_code==='string'?result.error_code:null,provider_type:typeof result?.error_type==='string'?result.error_type:null,provider_field:typeof result?.field_name==='string'?result.field_name:null},502);}
  return json({link_token:result.link_token,expiration:result.expiration||null,environment:plaidEnv});
 }catch{return json({code:'BANKING_UNAVAILABLE'},503);}
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
