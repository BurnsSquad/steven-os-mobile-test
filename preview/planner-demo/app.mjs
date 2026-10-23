import {members,seed,createItem,canEdit,renameItem,assignItem,canComplete,completeItem,isComplete} from './model.mjs';
const $=id=>document.getElementById(id),name=id=>members.find(m=>m.id===id)?.label||id;
let actor='adult',tab='task',items=seed(),editing=null;
const adult=()=>actor==='adult';
function status(text){$('status').textContent=text;}
for(const m of members){for(const id of ['actor','assignee','edit-assignee']){const option=document.createElement('option');option.value=m.id;option.textContent=m.label;$(id).append(option);}}
$('assignee').value='river';$('edit-assignee').value='river';
const assigned=(mode,id)=>mode==='individual'?[id]:['river','sky'];
function render(){
 $('tasks-tab').setAttribute('aria-pressed',String(tab==='task'));$('activities-tab').setAttribute('aria-pressed',String(tab==='activity'));
 $('heading').textContent=tab==='task'?'Household Tasks':'Activities for your day';
 $('permission-note').textContent=adult()?'Adult demo: manage all items. Everyone can see this shared planner.':tab==='task'?'You can complete your assigned Tasks and eligible household Tasks. Adults create Tasks.':'Create and edit your own Activities. Other members can see them.';
 $('create-panel').hidden=!adult()&&tab==='task';$('assignment-controls').hidden=!adult();
 $('create-heading').textContent=tab==='task'?'Add a Task':'Add an Activity';$('create-button').textContent=tab==='task'?'Add Task':'Add Activity';
 $('assignee-label').hidden=$('mode').value!=='individual';
 const visible=items.filter(x=>x.type===tab);$('count').textContent=`${visible.filter(isComplete).length} of ${visible.length} complete`;$('items').replaceChildren();
 for(const item of visible){
 const li=document.createElement('li');li.dataset.id=item.id;li.className=isComplete(item)?'complete':'';
 const title=document.createElement('h3');title.textContent=item.title;li.append(title);
 const detail=document.createElement('p');detail.className='muted';detail.textContent=item.mode==='household'?'Household · either eligible child can finish once':item.mode==='shared'?`Shared · ${item.completions.length}/${item.assignees.length} contributions`:`Assigned to ${name(item.assignees[0])}`;li.append(detail);
 if(item.mode==='shared'){const progress=document.createElement('p');progress.className='contributions';progress.textContent=item.assignees.map(id=>`${item.completions.some(c=>c.member===id)?'✓':'○'} ${name(id)}`).join(' · ');li.append(progress);}
 const actions=document.createElement('div');actions.className='actions';
 const targets=adult()&&item.mode!=='household'?item.assignees:[actor];
 for(const target of targets){if(canComplete(actor,item,target)){const button=document.createElement('button');button.type='button';button.textContent=target===actor?'Mark complete':`Complete for ${name(target)}`;button.dataset.complete=target;button.addEventListener('click',()=>{try{items=items.map(x=>x.id===item.id?completeItem(actor,x,target):x);status('Completion recorded in this fictional demo.');render();}catch(e){status(e.message);}});actions.append(button);}}
 if(canEdit(actor,item)){const edit=document.createElement('button');edit.type='button';edit.className='secondary';edit.textContent='Edit';edit.addEventListener('click',()=>{editing=item.id;$('edit-title').value=item.title;$('edit-mode').value=item.mode;$('edit-assignee').value=item.assignees[0];$('edit-assignment').hidden=!adult();$('edit-mode').disabled=item.completions.length>0;$('edit-assignee').disabled=item.completions.length>0;$('edit-dialog').showModal();});actions.append(edit);}
 if(!actions.childElementCount&&!isComplete(item)){const note=document.createElement('span');note.className='muted';note.textContent='Visible to you · assigned to someone else';actions.append(note);}li.append(actions);
 if(item.completions.length){const record=document.createElement('p');record.className='muted';record.textContent=item.completions.map(c=>`${name(c.actor)} recorded completion${c.actor!==c.member?' for '+name(c.member):''}`).join(' · ');li.append(record);}
 if(isComplete(item)){const done=document.createElement('strong');done.textContent='Complete';done.className='done-label';li.append(done);}$('items').append(li);
 }
 if(!visible.length){const empty=document.createElement('li');empty.textContent='No items here yet.';$('items').append(empty);}
}
$('actor').addEventListener('change',()=>{actor=$('actor').value;editing=null;$('edit-dialog').close();$('title').value='';status('Fictional role view changed; no real account was changed.');render();});
for(const [id,type] of [['tasks-tab','task'],['activities-tab','activity']])$(id).addEventListener('click',()=>{tab=type;render();});
$('mode').addEventListener('change',render);
$('create').addEventListener('submit',e=>{e.preventDefault();try{const mode=adult()?$('mode').value:'individual';const item=createItem(actor,{type:tab,title:$('title').value,mode,assignees:adult()?assigned(mode,$('assignee').value):[actor]},crypto.randomUUID());items.push(item);$('title').value='';status(`${tab==='task'?'Task':'Activity'} added to the fictional demo. Reloading clears demo changes.`);render();}catch(error){status(error.message);}});
$('edit').addEventListener('submit',e=>{e.preventDefault();try{items=items.map(item=>{if(item.id!==editing)return item;let next=renameItem(actor,item,$('edit-title').value);if(adult()&&!item.completions.length)next=assignItem(actor,next,$('edit-mode').value,assigned($('edit-mode').value,$('edit-assignee').value));return next;});$('edit-dialog').close();status('Fictional item updated.');render();}catch(error){status(error.message);}});
$('cancel-edit').addEventListener('click',()=>$('edit-dialog').close());
$('reset').addEventListener('click',()=>{items=seed();status('Fictional demo reset. No database records were changed.');render();});
render();
