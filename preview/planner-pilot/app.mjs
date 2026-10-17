import {createClient} from './api.mjs';
import {PUBLISHABLE_KEY} from './config.mjs';
const $=id=>document.getElementById(id),client=createClient();
let roster=[];const label=id=>roster.find(x=>x.id===id)?.label||'Household member';
let user=null,membership=null,items=[],tab='task',busy=false,editing=null,assigning=null,generation=0;
const adult=()=>membership?.member_role==='adult';
function message(text,error=false){$('status').textContent=text;$('status').dataset.error=String(error);}
function clear(){generation++;client.clear();user=null;membership=null;items=[];roster=[];editing=null;assigning=null;for(const id of ['edit-dialog','assign-dialog'])$(id).close();$('workspace').hidden=true;$('signin').hidden=false;$('password').value='';$('key').value='';$('title').value='';$('identity').textContent='';$('sync').textContent='';$('items').replaceChildren();}
function errorMessage(error){
 if(['SESSION','MEMBERSHIP','ISOLATION','EXPOSURE'].includes(error.code)){clear();message(error.code==='MEMBERSHIP'?'This account has no access to this planner.':['ISOLATION','EXPOSURE'].includes(error.code)?'The API configuration could not be verified. The page stopped; contact the developer.':'Your session ended. Sign in again.',true);}
 else if(error.code==='SIGNIN')message('Sign-in failed. Check the email address and password.',true);
 else if(error.code==='RATE_LIMIT'||error.status===429)message('Too many requests. Wait a moment before trying again.',true);
 else if(error.code==='42501'||error.status===403)message('Your account is not allowed to make that change.',true);
 else if(error.code==='40001')message('This item changed elsewhere. Review the refreshed list and open its controls again.',true);
 else if(error.code==='55000')message('Someone has already contributed. Assignments are now locked.',true);
 else if(error.code==='22023')message('Check the name and selected participants.',true);
 else message('The change could not be confirmed. Refresh before trying again.',true);
}
function lock(){for(const el of document.querySelectorAll('button,input,select'))el.disabled=busy||el.dataset.locked==='true';}
async function action(work){if(busy)return;busy=true;lock();try{await work();}catch(error){if(error.code==='40001'){editing=null;assigning=null;$('edit-dialog').close();$('assign-dialog').close();try{await load();}catch(other){errorMessage(other);return;}}errorMessage(error);}finally{busy=false;render();lock();}}
async function load(){const current=generation;if(!user)return;const m=await client.membership();const rows=await client.list();if(current!==generation||!user)return;membership=m;items=rows;$('sync').textContent=`Last checked ${new Date().toLocaleTimeString()}. Updates every 15 seconds while visible.`;render();}
function participants(container,prefix){for(const person of roster){const row=document.createElement('label');row.className='participant';const check=document.createElement('input');check.type='checkbox';check.value=person.id;check.id=prefix+person.id;row.append(check,document.createTextNode(person.label));container.append(row);}}
function buildRoster(rows){
 roster=rows.map((p,i)=>({id:p.user_id,label:p.user_id===user.id?'You':`${p.member_role==='adult'?'Adult':'Child'} ${i+1}`}));
 for(const id of ['assignee','assign-person']){$(id).replaceChildren();for(const person of roster){const option=document.createElement('option');option.value=person.id;option.textContent=person.label;$(id).append(option);}}
 $('participant-options').replaceChildren();$('assign-participants').replaceChildren();participants($('participant-options'),'create-');participants($('assign-participants'),'assign-');$('assignee').value=user.id;for(const p of roster)$('create-'+p.id).checked=true;
}
function selected(container){return [...$(container).querySelectorAll('input:checked')].map(x=>x.value);}
function modeControls(){$('assignee-label').hidden=$('mode').value!=='individual';$('participants').hidden=$('mode').value==='individual';$('assign-person-label').hidden=$('assign-mode').value!=='individual';$('assign-participants').hidden=$('assign-mode').value==='individual';}
function button(text,handler,secondary=false){const b=document.createElement('button');b.type='button';b.textContent=text;if(secondary)b.className='secondary';b.addEventListener('click',handler);return b;}
function canComplete(item,target){if(item.complete)return false;if(item.completion_mode==='household')return target===user.id&&(adult()||item.assignees.includes(user.id));return item.assignees.includes(target)&&(adult()||target===user.id)&&!item.completions.some(c=>c.assignee_id===target);}
function render(){
 if(!user||!membership)return;
 $('tasks-tab').setAttribute('aria-pressed',String(tab==='task'));$('activities-tab').setAttribute('aria-pressed',String(tab==='activity'));
 $('heading').textContent=tab==='task'?'Household Tasks':'Activities for your day';
 $('permission-note').textContent=adult()?'Manage household items and assignments. Everyone in this planner can see them.':tab==='task'?'Complete your assigned and eligible household Tasks. Adults create Tasks.':'Create and rename your own Activities. Other members can see them.';
 $('create-panel').hidden=!adult()&&tab==='task';$('assignment-controls').hidden=!adult();$('create-heading').textContent=tab==='task'?'Add a Task':'Add an Activity';$('create-button').textContent=tab==='task'?'Add Task':'Add Activity';
 const visible=items.filter(i=>i.item_type===tab);$('count').textContent=`${visible.filter(i=>i.complete).length} of ${visible.length} complete`;$('items').replaceChildren();
 for(const item of visible){
  const li=document.createElement('li');li.dataset.id=item.id;li.classList.toggle('complete',item.complete);
  const title=document.createElement('h3');title.textContent=item.title;li.append(title);
  const detail=document.createElement('p');detail.className='muted';detail.textContent=item.completion_mode==='household'?'Household · complete once':item.completion_mode==='shared'?`Shared · ${item.completions.length}/${item.assignees.length} contributions`:`Assigned to ${label(item.assignees[0])}`;li.append(detail);
  if(item.completion_mode==='shared'){const progress=document.createElement('p');progress.className='contributions';progress.textContent=item.assignees.map(id=>`${item.completions.some(c=>c.assignee_id===id)?'✓':'○'} ${label(id)}`).join(' · ');li.append(progress);}
  const actions=document.createElement('div');actions.className='actions';const targets=adult()&&item.completion_mode!=='household'?item.assignees:[user.id];
  for(const target of targets)if(canComplete(item,target)){const b=button(target===user.id?'Mark complete':`Complete for ${label(target)}`,()=>action(async()=>{await client.complete(item,target);await load();message('Completion saved. Other devices will see it on refresh.');}));b.dataset.complete=target;actions.append(b);}
  if(adult()||(item.item_type==='activity'&&item.created_by===user.id))actions.append(button('Rename',()=>{editing={...item};$('edit-title').value=item.title;$('edit-dialog').showModal();},true));
  if(adult()&&!item.completions.length)actions.append(button('Assignment',()=>{assigning={...item};$('assign-mode').value=item.completion_mode;$('assign-person').value=item.assignees[0];for(const c of $('assign-participants').querySelectorAll('input'))c.checked=item.assignees.includes(c.value);modeControls();$('assign-dialog').showModal();},true));
  if(!item.complete&&!actions.childElementCount){const note=document.createElement('p');note.className='muted';note.textContent=item.completion_mode==='shared'&&item.completions.some(c=>c.assignee_id===user.id)?'Your part is complete. Waiting for the remaining contributions.':'Visible to you · assigned to someone else';li.append(note);}li.append(actions);
  if(item.completions.length){const note=document.createElement('p');note.className='muted';note.textContent=item.completions.map(c=>`${label(c.actor_id)} recorded completion${c.actor_id!==c.assignee_id?' for '+label(c.assignee_id):''}`).join(' · ');li.append(note);}
  if(item.complete){const note=document.createElement('strong');note.className='done-label';note.textContent='Complete';li.append(note);}$('items').append(li);
 }
 if(!visible.length){const empty=document.createElement('li');empty.textContent=tab==='task'?'No household Tasks yet.':'No Activities yet.';$('items').append(empty);}modeControls();lock();
}
$('login').addEventListener('submit',event=>{event.preventDefault();action(async()=>{
 const password=$('password').value,key=PUBLISHABLE_KEY||$('key').value.trim(),account=$('email').value.trim();$('password').value='';
 try{user=await client.signIn(account,key,password);await client.checkExposure();generation++;membership=await client.membership();buildRoster(await client.roster());$('identity').textContent=`${user.email} · ${membership.member_role==='adult'?'Adult':'Child'}`;await load();$('signin').hidden=true;$('workspace').hidden=false;$('key').value='';message('Your shared planner is ready.');}catch(error){clear();throw error;}
});});
$('create').addEventListener('submit',event=>{event.preventDefault();action(async()=>{const mode=adult()?$('mode').value:'individual';const ids=adult()?(mode==='individual'?[$('assignee').value]:selected('participant-options')):[user.id];if(!ids.length){message('Choose at least one participant.',true);return;}await client.create({id:crypto.randomUUID(),type:tab,title:$('title').value.trim(),mode,assignees:ids});$('title').value='';await load();message(`${tab==='task'?'Task':'Activity'} saved to your household planner.`);});});
$('edit').addEventListener('submit',event=>{event.preventDefault();action(async()=>{if(!editing)return;await client.rename(editing,$('edit-title').value.trim());$('edit-dialog').close();editing=null;await load();message('Name saved.');});});
$('assign').addEventListener('submit',event=>{event.preventDefault();action(async()=>{if(!assigning)return;const mode=$('assign-mode').value,ids=mode==='individual'?[$('assign-person').value]:selected('assign-participants');if(!ids.length){message('Choose at least one participant.',true);return;}await client.assign(assigning,mode,ids);$('assign-dialog').close();assigning=null;await load();message('Assignment saved.');});});
for(const [id,type] of [['tasks-tab','task'],['activities-tab','activity']])$(id).addEventListener('click',()=>{tab=type;render();});
for(const id of ['mode','assign-mode'])$(id).addEventListener('change',modeControls);
$('cancel-edit').addEventListener('click',()=>$('edit-dialog').close());$('cancel-assign').addEventListener('click',()=>$('assign-dialog').close());
$('refresh').addEventListener('click',()=>action(async()=>{await load();message('Planner refreshed.');}));
$('signout').addEventListener('click',()=>action(async()=>{try{await client.signOut();message('Signed out.');}catch{message('Signed out on this page. The server could not confirm session revocation.',true);}finally{clear();}}));
setInterval(()=>{if(user&&!busy&&!document.hidden)action(()=>load());},15000);
document.addEventListener('visibilitychange',()=>{if(user&&!busy&&!document.hidden)action(()=>load());});
$('key-label').hidden=Boolean(PUBLISHABLE_KEY);modeControls();
// Session tokens stay in memory only. No localStorage/sessionStorage or legacy records.
