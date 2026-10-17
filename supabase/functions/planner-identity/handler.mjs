const validName=s=>typeof s==='string'&&/^[A-Za-z][A-Za-z0-9_]{2,23}$/.test(s);
// No credentials or identities are logged. No administrative key is returned.
export function createHandler({base,publicKey,adminKey,fetcher=fetch,clock=Date.now}){
 const attempts=new Map();
 const trustedOrigin=o=>/^https:\/\/steven-os-mobile-test-[a-z0-9]+-burns6\.vercel\.app$/.test(o);
 return async function handler(req){
  const origin=req.headers.get('origin')||'';
  const headers={'Content-Type':'application/json','Cache-Control':'no-store','Vary':'Origin',...(trustedOrigin(origin)?{'Access-Control-Allow-Origin':origin,'Access-Control-Allow-Headers':'authorization, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'}:{})};
  const reply=(body,status=200)=>new Response(JSON.stringify(body),{status,headers});
  if(origin&&!trustedOrigin(origin))return reply({code:'REQUEST'},403);
  if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
  if(req.method!=='POST')return reply({code:'REQUEST'},405);
  if(!base||!publicKey||!adminKey||!base.startsWith('https://'))return reply({code:'UNAVAILABLE'},503);
  async function send(path,{method='GET',body,admin=false,token}={}){
   const key=admin?adminKey:publicKey;
   const r=await fetcher(base+path,{method,redirect:'error',credentials:'omit',cache:'no-store',signal:AbortSignal.timeout(15000),headers:{apikey:key,...(token?{Authorization:`Bearer ${token}`} :admin&&adminKey.startsWith('eyJ')?{Authorization:`Bearer ${adminKey}`} :{}),'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)})});
   return {ok:r.ok,status:r.status,data:await r.json().catch(()=>null)};
  }
  try{
   if(Number(req.headers.get('content-length')||0)>4096)return reply({code:'REQUEST'},413);
   const reader=req.body?.getReader();if(!reader)return reply({code:'REQUEST'},400);
   const chunks=[];let size=0;while(true){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>4096){await reader.cancel();return reply({code:'REQUEST'},413);}chunks.push(value);}
   const bytes=new Uint8Array(size);let offset=0;for(const v of chunks){bytes.set(v,offset);offset+=v.length;}
   const body=JSON.parse(new TextDecoder().decode(bytes));
   if(!['signin','rename'].includes(body.action))return reply({code:'REQUEST'},400);
   // Best-effort isolate throttling supplements Auth's provider-wide controls.
   // It is not a claim of a globally coordinated rate limiter.
   const bucket=body.action==='signin'?String(body.username||'').toLowerCase():req.headers.get('authorization')||'anonymous';
   const now=clock();for(const [k,v] of attempts)if(v.until<now)attempts.delete(k);
   if(attempts.size>10000)return reply({code:'RATE_LIMIT'},429);
   const count=attempts.get(bucket)||{n:0,until:now+600000};count.n++;attempts.set(bucket,count);
   if(count.n>20)return reply({code:'RATE_LIMIT'},429);
   if(body.action==='signin'){
    if(!validName(body.username)||typeof body.password!=='string'||!body.password||body.password.length>256)return reply({code:'SIGNIN'},401);
    const name=body.username.toLowerCase();
    const found=await send('/rest/v1/bb_planner_profiles?'+new URLSearchParams({select:'user_id,username',username_key:`eq.${name}`}),{admin:true});
    if(!found.ok)return reply({code:'UNAVAILABLE'},503);
    const profile=Array.isArray(found.data)&&found.data.length===1?found.data[0]:null;
    const identity=profile?await send('/auth/v1/admin/users/'+encodeURIComponent(profile.user_id),{admin:true}):null;
    const email=identity?.ok?identity.data?.email:null;
    // Unknown handles still go through ordinary Auth; no email lookup endpoint.
    const auth=await send('/auth/v1/token?grant_type=password',{method:'POST',body:{email:email||'unregistered-login@users.invalid',password:body.password}});
    if(auth.status===429)return reply({code:'RATE_LIMIT'},429);
    if(!profile||!email||!auth.ok||auth.data?.user?.id!==profile.user_id||typeof auth.data?.access_token!=='string')return reply({code:'SIGNIN'},401);
    return reply({access_token:auth.data.access_token,refresh_token:auth.data.refresh_token,expires_in:auth.data.expires_in,actor_id:profile.user_id});
   }
   const token=/^Bearer (.+)$/.exec(req.headers.get('authorization')||'')?.[1];
   if(!token)return reply({code:'SESSION'},401);
   const verified=await send('/auth/v1/user',{token});
   if(!verified.ok||typeof verified.data?.id!=='string'||!verified.data?.email)return reply({code:'SESSION'},401);
   if(!validName(body.username)||typeof body.password!=='string'||!body.password||body.password.length>256)return reply({code:'USERNAME'},400);
   const actor=verified.data;
   const member=await send('/rest/v1/bb_planner_members?'+new URLSearchParams({select:'household_id,user_id,member_role',user_id:`eq.${actor.id}`}),{token});
   if(!member.ok||!Array.isArray(member.data)||member.data.length!==1||member.data[0].user_id!==actor.id)return reply({code:'MEMBERSHIP'},403);
   const auth=await send('/auth/v1/token?grant_type=password',{method:'POST',body:{email:actor.email,password:body.password}});
   if(auth.status===429)return reply({code:'RATE_LIMIT'},429);
   if(!auth.ok||auth.data?.user?.id!==actor.id)return reply({code:'PASSWORD'},403);
   if(typeof auth.data.access_token==='string')await send('/auth/v1/logout?scope=local',{method:'POST',token:auth.data.access_token}).catch(()=>{});
   const before=await send('/rest/v1/bb_planner_profiles?'+new URLSearchParams({select:'user_id',user_id:`eq.${actor.id}`}),{admin:true});
   if(!before.ok||!Array.isArray(before.data))return reply({code:'UNAVAILABLE'},503);
   const existing=before.data.length===1;
   const updated=await send('/rest/v1/bb_planner_profiles'+(existing?'?'+new URLSearchParams({user_id:`eq.${actor.id}`}):''),{method:existing?'PATCH':'POST',admin:true,body:existing?{username:body.username,updated_at:new Date(now).toISOString()}:{user_id:actor.id,household_id:member.data[0].household_id,username:body.username}});
   if(updated.status===409)return reply({code:'USERNAME_TAKEN'},409);
   if(!updated.ok)return reply({code:'UNAVAILABLE'},503);
   const confirmed=await send('/rest/v1/bb_planner_profiles?'+new URLSearchParams({select:'user_id,username',user_id:`eq.${actor.id}`}),{admin:true});
   if(!confirmed.ok||confirmed.data?.length!==1||confirmed.data[0].username!==body.username)return reply({code:'UNCONFIRMED'},503);
   // Return only the label. UUIDs, role, email and recovery destination do not change.
   return reply({username:body.username});
  }catch{return reply({code:'REQUEST'},400);}
 };
}
