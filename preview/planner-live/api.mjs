// Ordinary authenticated client only. No privileged key, role selector or storage.
export const ORIGIN='https://wozynsftofkjqwlflosv.supabase.co';
export const HOUSEHOLD='bba90000-0000-4000-8000-000000000001';
export const ACCOUNTS={a:{id:'6fe4e705-a92f-44ea-9898-d0eebf1f95d5',email:'burns-security-a@example.test',label:'Account A'},b:{id:'fd9810b3-6190-4587-b33c-81de6564a5dc',email:'burns-security-b@example.test',label:'Account B'},c:{id:'bb0bed90-1037-419f-a385-90e543575864',email:'burns-security-c@example.test',label:'Account C'}};
export class ClientError extends Error{constructor(code,status=0){super(code);this.code=code;this.status=status;}}
export function createClient(fetcher=fetch){
 let session=null,epoch=0;const controllers=new Set();
 function clear(){epoch++;session=null;for(const c of controllers)c.abort();controllers.clear();}
 async function send(path,{method='GET',body,key,token,profile}={}){
  if(!/^sb_publishable_[A-Za-z0-9_-]+$/.test(key||'')||!/^\/(auth|rest)\/v1\//.test(path))throw new ClientError('CONFIG');
  const controller=new AbortController();controllers.add(controller);const timer=setTimeout(()=>controller.abort(),20000);
  try{const response=await fetcher(ORIGIN+path,{method,redirect:'error',credentials:'omit',cache:'no-store',referrerPolicy:'no-referrer',signal:controller.signal,headers:{apikey:key,...(token?{Authorization:`Bearer ${token}`} : {}),Accept:'application/json',...(profile?{'Accept-Profile':profile}:{}),...(body===undefined?{}:{'Content-Type':'application/json'})},...(body===undefined?{}:{body:JSON.stringify(body)})});
   const data=await response.json().catch(()=>null);
   if(!response.ok)throw new ClientError(typeof data?.code==='string'?data.code:response.status===401?'SESSION':response.status===429?'RATE_LIMIT':'REQUEST',response.status);
   return data;
  }catch(error){if(error instanceof ClientError)throw error;throw new ClientError('NETWORK');}finally{clearTimeout(timer);controllers.delete(controller);}
 }
 async function mutation(name,body,id){const result=await request('/rest/v1/rpc/'+name,{method:'POST',body});if(result?.id!==id||result.household_id!==HOUSEHOLD)throw new ClientError('UNCONFIRMED');return result;}
 function tokenState(data,key,user){if(typeof data?.access_token!=='string'||typeof data?.refresh_token!=='string')throw new ClientError('SESSION');return {key,token:data.access_token,refresh:data.refresh_token,expires:Date.now()+(Number(data.expires_in)||3600)*1000,user};}
 async function refresh(){const old=session,version=epoch;if(!old)throw new ClientError('SESSION');
  try{const data=await send('/auth/v1/token?grant_type=refresh_token',{method:'POST',body:{refresh_token:old.refresh},key:old.key});if(version!==epoch||session!==old)throw new ClientError('SESSION');session=tokenState(data,old.key,old.user);}catch(error){clear();throw new ClientError('SESSION');}
 }
 async function request(path,options={},retried=false){if(!session)throw new ClientError('SESSION');if(session.expires<Date.now()+30000)await refresh();const version=epoch,current=session;
  try{const data=await send(path,{...options,key:current.key,token:current.token});if(epoch!==version)throw new ClientError('SESSION');return data;}catch(error){if(error.status===401&&session===current&&!retried){await refresh();return request(path,options,true);}if(error.status===401){clear();throw new ClientError('SESSION');}throw error;}
 }
 return {
  async signIn(account,key,password){clear();const actor=ACCOUNTS[account];if(!actor||!password)throw new ClientError('SIGNIN');const version=epoch;
   try{const data=await send('/auth/v1/token?grant_type=password',{method:'POST',body:{email:actor.email,password},key});if(epoch!==version)throw new ClientError('SESSION');const pending=tokenState(data,key,null);const user=await send('/auth/v1/user',{key,token:pending.token});if(epoch!==version||user?.id!==actor.id||user?.email!==actor.email)throw new ClientError('SESSION');session={...pending,user};return user;}catch(error){clear();throw new ClientError(error.status===429?'RATE_LIMIT':'SIGNIN');}
  },
  async membership(){const rows=await request('/rest/v1/bb_planner_members?'+new URLSearchParams({select:'household_id,user_id,member_role',household_id:`eq.${HOUSEHOLD}`,user_id:`eq.${session.user.id}`}));if(!Array.isArray(rows)||rows.length!==1||rows[0].user_id!==session.user.id||rows[0].household_id!==HOUSEHOLD||!['adult','child'].includes(rows[0].member_role))throw new ClientError('MEMBERSHIP');return rows[0];},
  async checkExposure(){try{await request('/rest/v1/rpc/actor_uid',{profile:'bb_planner_private'});}catch(error){if(error.code==='PGRST106')return true;throw new ClientError(error.code==='NETWORK'?'NETWORK':'EXPOSURE');}throw new ClientError('EXPOSURE');},
  async list(){const rows=await request('/rest/v1/rpc/bb_planner_list',{method:'POST',body:{h:HOUSEHOLD}});if(!Array.isArray(rows)||rows.some(x=>x.household_id!==HOUSEHOLD||!['task','activity'].includes(x.item_type)||!Array.isArray(x.assignees)||!Array.isArray(x.completions)))throw new ClientError('ISOLATION');return rows;},
  async create({id,type,title,mode,assignees}){return mutation('bb_planner_create',{h:HOUSEHOLD,i:id,k:type,t:title,m:mode,ids:assignees},id);},
  async rename(item,title){return mutation('bb_planner_rename',{i:item.id,t:title,v:item.version},item.id);},
  async assign(item,mode,assignees){return mutation('bb_planner_assign',{i:item.id,m:mode,ids:assignees,v:item.version},item.id);},
  async complete(item,member){return mutation('bb_planner_complete',{i:item.id,for_member:member},item.id);},
  async signOut(){const old=session;clear();if(old)await send('/auth/v1/logout?scope=local',{method:'POST',key:old.key,token:old.token});},
  clear
 };
}
