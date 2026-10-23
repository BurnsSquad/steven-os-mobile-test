// Parent-only controls. All authorization and version checks also run in Postgres.
export function routineControls({client,host,people,onError,onSaved}){
 let routines=[],busy=false,epoch=0;
 const names=ids=>ids.map(id=>people().find(p=>p.id===id)?.label||'Household member').join(', ');
 const clock=time=>{const [h,m]=time.split(':').map(Number);return `${h%12||12}:${String(m).padStart(2,'0')} ${h>=12?'PM':'AM'}`;};
 const days=['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
 function node(tag,text){const e=document.createElement(tag);if(text!==undefined)e.textContent=text;return e;}
 function field(form,text,input){input.setAttribute('aria-label',text);const label=node('label',text);label.append(input);form.append(label);return input;}
 function input(type,value){const e=node('input');e.type=type;if(type==='checkbox')e.checked=!!value;else e.value=value;return e;}
 function choose(values,current){const e=node('select');for(const [value,label]of values){const o=node('option',label);o.value=value;e.append(o);}e.value=current;return e;}
 function btn(text,fn){const e=node('button',text);e.type='button';e.className='secondary';e.onclick=fn;return e;}
 async function save(form,work){if(busy)return;const current=epoch;busy=true;host.querySelectorAll('button,input,select').forEach(e=>e.disabled=true);try{const changed=await work();if(current!==epoch)return;routines=routines.map(r=>r.id===changed.id?changed:r);render();onSaved('Routine saved. Future Tasks use these settings; existing Tasks and completions are unchanged.');}catch(error){if(current!==epoch)return;onError(error);if(error.code==='40001'){try{await load();}catch(e){onError(e);}}}finally{busy=false;if(current===epoch)host.querySelectorAll('button,input,select').forEach(e=>e.disabled=false);}}
 function taskForm(r,t){const form=node('form');form.className='routine-form';const title=field(form,'Repeating Task',input('text',t?.title||''));title.required=true;title.maxLength=105;
 const mode=field(form,'How is it finished?',choose([['individual','One assigned person'],['household','Household — complete once'],['shared',"Shared — each person's part"]],t?.mode||'individual'));
 const who=node('fieldset');who.append(node('legend','Participants'));const checks=[];for(const p of people()){const l=node('label');l.className='participant';const c=input('checkbox',t?.assignees.includes(p.id)||false);c.value=p.id;checks.push(c);l.append(c,document.createTextNode(p.label));who.append(l);}form.append(who);
 const active=field(form,'Repeat this Task',input('checkbox',t?.enabled??true));const submit=node('button','Save repeating Task');submit.type='submit';form.append(submit,btn('Cancel',()=>form.remove()));
 form.onsubmit=e=>{e.preventDefault();const ids=checks.filter(c=>c.checked).map(c=>c.value);if(!ids.length||(mode.value==='individual'&&ids.length!==1)){onSaved('Choose one person for an individual Task, or participants for Household/Shared.');return;}save(form,()=>client.saveRoutineTask(r,{id:t?.id||null,title:title.value.trim(),mode:mode.value,assignees:ids,enabled:active.checked}));};return form;}
 function render(){host.replaceChildren();host.append(node('h2','Repeating routines'),node('p','Choose when future Tasks appear. Existing Tasks and completion history stay saved. Times use Eastern Time, including daylight saving.'));
 if(!routines.length){host.append(node('p','No repeating routines have been set up yet.'));return;}
 for(const r of routines){const section=node('section');section.className='routine';section.append(node('h3','Prepare for tomorrow'));
 const summary=node('p',(r.enabled?'Active':'Paused')+' · '+clock(r.time)+' Eastern · '+r.weekdays.map(d=>days[d-1]).join(', '));summary.className='muted';section.append(summary);
 const details=node('details');details.append(node('summary','Edit days, time or pause'));const form=node('form');form.className='routine-form';const [hours,minutes]=r.time.split(':').map(Number);const timeFields=node('fieldset');timeFields.append(node('legend','Start time (Eastern)'));const hour=field(timeFields,'Hour',choose(Array.from({length:12},(_,i)=>[String(i+1),String(i+1)]),String(hours%12||12)));const minute=field(timeFields,'Minute',choose(Array.from({length:60},(_,i)=>[String(i).padStart(2,'0'),String(i).padStart(2,'0')]),String(minutes).padStart(2,'0')));const period=field(timeFields,'AM or PM',choose([['AM','AM'],['PM','PM']],hours>=12?'PM':'AM'));form.append(timeFields);
 const weekdays=node('fieldset');weekdays.append(node('legend','Repeat on'));const chosen=[];days.forEach((name,i)=>{const l=node('label');l.className='participant';const c=input('checkbox',r.weekdays.includes(i+1));c.value=i+1;chosen.push(c);l.append(c,document.createTextNode(name));weekdays.append(l);});form.append(weekdays);
 const enabled=field(form,'Routine enabled',input('checkbox',r.enabled));const submit=node('button','Save routine');submit.type='submit';form.append(submit);form.onsubmit=e=>{e.preventDefault();const ds=chosen.filter(c=>c.checked).map(c=>Number(c.value));if(!ds.length){onSaved('Choose at least one day. To stop all days, turn Routine enabled off.');return;}save(form,()=>client.saveRoutine(r,{time:String(Number(hour.value)%12+(period.value==='PM'?12:0)).padStart(2,'0')+':'+minute.value,weekdays:ds,enabled:enabled.checked}));};details.append(form);section.append(details);
 for(const t of r.templates){const row=node('div');row.className='routine-task';row.append(node('h4',t.title),node('p',(t.enabled?'Repeats':'Paused')+' · '+names(t.assignees)+' · '+t.mode),btn('Edit repeating Task',()=>{if(!row.querySelector('form'))row.append(taskForm(r,t));}));section.append(row);}
 section.append(btn('Add repeating Task',()=>{if(!section.querySelector(':scope > form'))section.append(taskForm(r,null));}));host.append(section);}
 }
 async function load(){const current=epoch;const rows=await client.routines();if(current!==epoch)return;routines=rows;render();}
 function clear(){epoch++;routines=[];host.replaceChildren();host.hidden=true;}
 return {load,clear};
}
