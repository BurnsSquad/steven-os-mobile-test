// Parent-requested local export. Explicit field selection excludes session/provider payloads.
const take=(value,keys)=>Object.fromEntries(keys.filter(k=>Object.hasOwn(value,k)).map(k=>[k,value[k]]));
export async function sharedHouseholdExport(client,{isCurrent=()=>true,now=()=>new Date().toISOString()}={}){
 const started=now(),membership=await client.membership();if(!isCurrent())throw Error('Export cancelled');if(membership.member_role!=='adult')throw Error('Only parents can export household data');
 const[items,events,groceries,routines,people,profiles]=await Promise.all([client.list(),client.calendarList(),client.groceries(),client.routines(),client.roster(),client.profiles()]);
 if(!isCurrent())throw Error('Export cancelled');
 const latest=await client.membership();if(!isCurrent()||latest.member_role!=='adult'||latest.household_id!==membership.household_id||latest.user_id!==membership.user_id)throw Error('Export membership changed');
 for(const rows of [items,events,groceries,routines,profiles])if(!Array.isArray(rows)||rows.some(r=>r.household_id!==membership.household_id))throw Error('Export household mismatch');
 const records={
  members:people.map(p=>({user_id:p.user_id,role:p.member_role,username:profiles.find(r=>r.user_id===p.user_id)?.username||null})),
  items:items.map(r=>({...take(r,['id','household_id','created_by','item_type','title','completion_mode','version','complete','created_at','updated_at']),assignees:[...r.assignees],completions:r.completions.map(c=>take(c,['id','assignee_id','actor_id','created_at','completed_at']))})),
  calendar_events:events.filter(r=>r.visibility==='family').map(r=>take(r,['id','household_id','created_by','title','starts_at','ends_at','all_day','visibility','notes','status','version','created_at','updated_at'])),
  grocery_items:groceries.map(r=>take(r,['id','household_id','created_by','title','quantity','is_picked','picked_by','picked_at','is_archived','version','created_at','updated_at'])),
  routines:routines.map(r=>({...take(r,['id','household_id','routine_key','time','weekdays','enabled','version','created_at','updated_at']),templates:r.templates.map(t=>take(t,['id','title','mode','assignees','enabled']))}))
 };
 const finished=now(),parts=Object.fromEntries(new Intl.DateTimeFormat('en-US',{timeZone:'America/New_York',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date(finished)).map(p=>[p.type,p.value]));
 const data={format:'burns-base-shared-household-export',format_version:1,household_id:membership.household_id,exported_by:membership.user_id,started_at:started,completed_at:finished,
  scope:'Current shared planner items and completions, family-visible calendar events, grocery items including archived, routine settings/templates and household usernames.',
  excluded:['Passwords, tokens, keys and account email fields','Original private OS source/workspaces/revisions','Finance records and paycheck plans','Private and Parents-only calendar events','Internal scheduler occurrence records and full audit history'],
  consistency:'Read across several authorized requests, not a single point-in-time database snapshot. Concurrent edits may span versions. No automatic restore/import is provided.',counts:Object.fromEntries(Object.entries(records).map(([k,v])=>[k,v.length])),records};
 return{name:`Burns_Base_Shared_Data_${parts.year}-${parts.month}-${parts.day}.json`,type:'application/json',text:JSON.stringify(data,null,2),counts:data.counts};
}
