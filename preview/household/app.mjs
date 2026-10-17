// Fictional sandbox UI. No imports, migration, legacy storage access or privileged key.
const ORIGIN='https://wozynsftofkjqwlflosv.supabase.co';
const ACTORS={a:{id:'6fe4e705-a92f-44ea-9898-d0eebf1f95d5',email:'burns-security-a@example.test'},b:{id:'fd9810b3-6190-4587-b33c-81de6564a5dc',email:'burns-security-b@example.test'},c:{id:'bb0bed90-1037-419f-a385-90e543575864',email:'burns-security-c@example.test'}};
const HOUSEHOLD='bba20000-0000-4000-8000-000000000001';
const $=id=>document.getElementById(id);
let session=null,rows=[],member=false,busy=false,generation=0;
const editable=row=>row?.id?.startsWith('bba80000-')&&row.household_id===HOUSEHOLD&&row.title?.startsWith('TEST ONLY - ');
function message(text,error=false){$('status').textContent=text;$('status').dataset.error=String(error);}
function locked(value){busy=value;for(const el of document.querySelectorAll('button,input,select'))el.disabled=value;}
function clearSession(){generation++;session=null;rows=[];member=false;$('tasks').replaceChildren();$('identity').textContent='';$('workspace').hidden=true;$('signin').hidden=false;$('password').value='';$('key').value='';}
async function request(path,{method='GET',body,auth=session}={}){
  if(!auth||!path.startsWith('/')||!(path.startsWith('/auth/v1/')||path.startsWith('/rest/v1/')))throw Error('REQUEST');
  const response=await fetch(ORIGIN+path,{method,redirect:'error',cache:'no-store',signal:AbortSignal.timeout(20000),headers:{apikey:auth.key,Authorization:`Bearer ${auth.token||auth.key}`,Accept:'application/json',...(body===undefined?{}:{'Content-Type':'application/json',Prefer:'return=representation'})},...(body===undefined?{}:{body:JSON.stringify(body)})});
  const data=await response.json().catch(()=>null);
  if(!response.ok){if(response.status===401)throw Error('SESSION');if(response.status===403)throw Error('DENIED');throw Error('REQUEST');}
  return data;
}
function handle(error){
  if(error?.message==='ISOLATION'){clearSession();message('Unexpected household access. The preview stopped; contact the developer before continuing.',true);}
  else if(error?.message==='SESSION'){clearSession();message('Your session ended. Sign in again.',true);}
  else if(error?.message==='DENIED')message('This account does not have permission for that action. No success was confirmed.',true);
  else message('The request could not be confirmed. Refresh before trying again.',true);
}
async function load(){
  const current=session,version=generation;if(!current)return;
  const [members,tasks]=await Promise.all([request('/rest/v1/bb_test_household_members?select=household_id,user_id,role',{auth:current}),request('/rest/v1/bb_test_shared_tasks?select=*&order=created_at.asc,id.asc',{auth:current})]);
  if(version!==generation||session!==current)return;
  if(!Array.isArray(members)||!Array.isArray(tasks))throw Error('REQUEST');
  if(members.some(m=>m.user_id!==current.user.id)||tasks.some(t=>t.household_id!==HOUSEHOLD)|| (current.user.id===ACTORS.c.id&&(members.length||tasks.length)))throw Error('ISOLATION');
  member=members.some(m=>m.household_id===HOUSEHOLD&&m.user_id===current.user.id);rows=tasks;render();
  $('sync').textContent=`Last checked ${new Date().toLocaleTimeString()}. Checks every 15 seconds while this tab is visible.`;
}
function render(){
  $('tasks').replaceChildren();$('create').hidden=!member;$('empty').hidden=rows.length>0;
  $('empty').textContent=member?'No shared tasks yet. Add a fictional task below.':'This account has no household membership. No household tasks are available.';
  for(const row of rows){
    const li=document.createElement('li');li.classList.toggle('done',row.completed);
    const check=document.createElement('input');check.type='checkbox';check.checked=row.completed;check.disabled=!editable(row);check.setAttribute('aria-label',`Mark ${row.title} ${row.completed?'incomplete':'complete'}`);
    check.addEventListener('change',()=>change(row,{completed:check.checked}));
    const text=document.createElement('div');text.className='task-body';const title=document.createElement('span');title.className='task-title';title.textContent=row.title.replace(/^TEST ONLY - /,'');
    const note=document.createElement('span');note.className='task-note';note.textContent=editable(row)?`Added by account ${row.created_by===ACTORS.a.id?'A':row.created_by===ACTORS.b.id?'B':'unknown'}`:'Preserved security baseline · read-only';text.append(title,note);li.append(check,text);
    if(editable(row)){const actions=document.createElement('div');actions.className='task-actions';const edit=document.createElement('button');edit.type='button';edit.className='secondary';edit.textContent='Rename';edit.addEventListener('click',()=>{const value=prompt('Fictional task name',row.title.replace(/^TEST ONLY - /,''));if(value!==null&&value.trim())change(row,{title:'TEST ONLY - '+value.trim().slice(0,120)});});actions.append(edit);li.append(actions);}
    $('tasks').append(li);
  }
}
async function action(work){if(busy)return;locked(true);try{await work();}catch(error){handle(error);}finally{locked(false);render();}}
async function change(row,body){
  return action(async()=>{
    if(!member||!editable(row)||Object.keys(body).some(k=>!['title','completed'].includes(k)))throw Error('DENIED');
    const data=await request('/rest/v1/bb_test_shared_tasks?select=*&'+new URLSearchParams({id:`eq.${row.id}`,household_id:`eq.${HOUSEHOLD}`,created_by:`eq.${row.created_by}`,title:`eq.${row.title}`,completed:`eq.${row.completed}`}),{method:'PATCH',body});
    if(!Array.isArray(data)||data.length!==1){await load();message('This task changed elsewhere. Review the refreshed list before editing again.',true);return;}
    await load();message('Shared task saved. The other device will see it on its next refresh.');
  });
}
$('login').addEventListener('submit',event=>{event.preventDefault();action(async()=>{
  const key=$('key').value.trim(),actor=ACTORS[$('account').value],password=$('password').value;$('password').value='';
  if(!/^sb_publishable_[A-Za-z0-9_-]+$/.test(key)||!actor||!password){message('Enter the sandbox publishable key and saved fictional-account password.',true);return;}
  const token=await request('/auth/v1/token?grant_type=password',{method:'POST',body:{email:actor.email,password},auth:{key}});
  if(typeof token?.access_token!=='string')throw Error('SESSION');
  const auth={key,token:token.access_token};const user=await request('/auth/v1/user',{auth});
  if(user?.id!==actor.id||user?.email!==actor.email)throw Error('SESSION');
  session={...auth,user};generation++;$('key').value='';$('identity').textContent=`Signed in as account ${$('account').value.toUpperCase()}`;$('signin').hidden=true;$('workspace').hidden=false;
  await load();message(member?'Your household task list is ready.':'Signed in. This account has no household membership.');
});});
$('create').addEventListener('submit',event=>{event.preventDefault();action(async()=>{
  const title=$('title').value.trim();if(!member||!title||!session)throw Error('DENIED');
  const id='bba80000-'+crypto.randomUUID().slice(9);
  const result=await request('/rest/v1/bb_test_shared_tasks?select=*',{method:'POST',body:{id,household_id:HOUSEHOLD,created_by:session.user.id,title:'TEST ONLY - '+title.slice(0,120),completed:false}});
  if(!Array.isArray(result)||result.length!==1||result[0].id!==id)throw Error('REQUEST');
  $('title').value='';await load();message('Fictional task added for both household members.');
});});
$('refresh').addEventListener('click',()=>action(async()=>{await load();message('Household list refreshed.');}));
$('signout').addEventListener('click',()=>action(async()=>{try{await request('/auth/v1/logout?scope=local',{method:'POST'});}finally{clearSession();message('Signed out on this page.');}}));
setInterval(()=>{if(session&&!busy&&!document.hidden)action(()=>load());},15000);
document.addEventListener('visibilitychange',()=>{if(session&&!busy&&!document.hidden)action(()=>load());});
// Tokens/passwords are never written to browser storage. Reload requires sign-in.
