import {ORIGIN,ClientError} from './api.mjs';
export function takeRecoveryLink(location,history){
 const params=new URLSearchParams(location.hash.replace(/^#/,''));
 // Clear tokens and provider errors from the visible URL before any request.
 history.replaceState(null,'',location.pathname);
 if(params.get('type')!=='recovery'||!params.get('access_token')||params.get('error'))throw new ClientError('RECOVERY_LINK');
 return params.get('access_token');
}
export function createRecoveryClient(fetcher=fetch){
 let token=null,key=null,actor=null,epoch=0;
 function clear(){epoch++;token=null;key=null;actor=null;}
 async function send(path,options={}){
  if(!token||!/^sb_publishable_[A-Za-z0-9_-]+$/.test(key||''))throw new ClientError('RECOVERY_LINK');
  const version=epoch;
  let r;try{r=await fetcher(ORIGIN+path,{method:options.method||'GET',redirect:'error',credentials:'omit',cache:'no-store',referrerPolicy:'no-referrer',signal:AbortSignal.timeout(20000),headers:{apikey:key,Authorization:`Bearer ${token}`,'Content-Type':'application/json'},...(options.body?{body:JSON.stringify(options.body)}:{})});}catch{throw new ClientError('NETWORK');}
  const data=await r.json().catch(()=>null);if(version!==epoch)throw new ClientError('RECOVERY_LINK');
  if(!r.ok)throw new ClientError(r.status===401?'RECOVERY_LINK':r.status===429?'RATE_LIMIT':data?.code==='weak_password'?'WEAK_PASSWORD':'REQUEST',r.status);
  return data;
 }
 return {
  async open(accessToken,publicKey){clear();token=accessToken;key=publicKey;
   try{const user=await send('/auth/v1/user');if(typeof user?.id!=='string')throw new ClientError('RECOVERY_LINK');
    const members=await send('/rest/v1/bb_planner_members?'+new URLSearchParams({select:'household_id,user_id',user_id:`eq.${user.id}`}));
    if(!Array.isArray(members)||members.length!==1||members[0].user_id!==user.id)throw new ClientError('RECOVERY_LINK');
    const profiles=await send('/rest/v1/bb_planner_profiles?'+new URLSearchParams({select:'household_id,user_id,username',user_id:`eq.${user.id}`}));
    if(!Array.isArray(profiles)||profiles.length!==1||profiles[0].user_id!==user.id||profiles[0].household_id!==members[0].household_id||typeof profiles[0].username!=='string')throw new ClientError('RECOVERY_LINK');
    actor=user.id;return profiles[0].username;
   }catch(error){clear();throw error;}
  },
  async save(password,confirmation){
   if(!actor)throw new ClientError('RECOVERY_LINK');
   if(typeof password!=='string'||password.length<12||password.length>256||password!==confirmation)throw new ClientError('PASSWORD_INPUT');
   const expected=actor,data=await send('/auth/v1/user',{method:'PUT',body:{password}});
   if(data?.id!==expected){clear();throw new ClientError('UNCONFIRMED');}
   let revoked=true;try{await send('/auth/v1/logout?scope=global',{method:'POST'});}catch{revoked=false;}finally{clear();}
   return {saved:true,revocationConfirmed:revoked};
  },clear
 };
}
