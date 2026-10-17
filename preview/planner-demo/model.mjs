// FICTIONAL UI SIMULATION ONLY. These client checks are not database authorization.
export const members=[{id:'adult',label:'Adult demo',role:'adult'},{id:'river',label:'River · fictional child',role:'child'},{id:'sky',label:'Sky · fictional child',role:'child'}];
const known=id=>members.some(m=>m.id===id);
const actorFor=id=>{const actor=members.find(m=>m.id===id);if(!actor)throw Error('Unknown demo actor');return actor;};
export function validate(item){
 if(!['task','activity'].includes(item.type)||!['individual','household','shared'].includes(item.mode)||!item.title?.trim())throw Error('Invalid item');
 if(!known(item.owner)||!Array.isArray(item.assignees)||!item.assignees.length||new Set(item.assignees).size!==item.assignees.length||!item.assignees.every(known))throw Error('Invalid assignments');
 if(item.mode==='individual'&&item.assignees.length!==1)throw Error('Individual items need one assignee');
 return item;
}
export function createItem(actorId,input,id){
 const actor=actorFor(actorId);
 if(actor.role==='child'&&(input.type!=='activity'||input.mode!=='individual'||input.assignees?.length!==1||input.assignees[0]!==actorId))throw Error('Children create self-assigned Activities only');
 return validate({id,...input,title:String(input.title||'').trim().slice(0,120),owner:actorId,completions:[],events:[{action:'created',actor:actorId}]});
}
export function canEdit(actorId,item){const actor=actorFor(actorId);return actor.role==='adult'||(item.type==='activity'&&item.owner===actorId);}
export function renameItem(actorId,item,title){
 if(!canEdit(actorId,item))throw Error('Cannot edit this item');
 const text=String(title||'').trim().slice(0,120);if(!text)throw Error('A title is required');
 return {...item,title:text,events:[...item.events,{action:'renamed',actor:actorId}]};
}
export function assignItem(actorId,item,mode,assignees){
 if(actorFor(actorId).role!=='adult')throw Error('Only adults assign household work');
 if(item.completions.length)throw Error('Completed contributions need a reviewed reassignment workflow');
 return validate({...item,mode,assignees:[...assignees],events:[...item.events,{action:'assigned',actor:actorId}]});
}
export function isComplete(item){return item.mode==='shared'?item.assignees.every(id=>item.completions.some(c=>c.member===id)):item.completions.length>0;}
export function canComplete(actorId,item,targetId=actorId){
 const actor=actorFor(actorId);if(isComplete(item))return false;
 if(item.mode==='household')return targetId===actorId&&(actor.role==='adult'||item.assignees.includes(actorId));
 if(!item.assignees.includes(targetId)||item.completions.some(c=>c.member===targetId))return false;
 return actor.role==='adult'||actorId===targetId;
}
export function completeItem(actorId,item,targetId=actorId,at=new Date().toISOString()){
 if(!canComplete(actorId,item,targetId))throw Error('Completion unavailable for this actor or contribution');
 const completion={member:targetId,actor:actorId,at};
 return {...item,completions:[...item.completions,completion],events:[...item.events,{action:'completed',...completion}]};
}
export function seed(){return [
 {id:'assigned-demo',type:'task',title:'Pack the fictional picnic blanket',owner:'adult',mode:'individual',assignees:['river'],completions:[],events:[]},
 {id:'household-demo',type:'task',title:'Fill the fictional bird feeder',owner:'adult',mode:'household',assignees:['river','sky'],completions:[],events:[]},
 {id:'shared-demo',type:'task',title:'Bring your own fictional game-night idea',owner:'adult',mode:'shared',assignees:['river','sky'],completions:[],events:[]},
 {id:'activity-demo',type:'activity',title:'Draw a fictional forest map',owner:'river',mode:'individual',assignees:['river'],completions:[],events:[]}
 ];}
