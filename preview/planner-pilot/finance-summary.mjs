// Parent-only read-only snapshot. Self-contained for the opaque original frame.
export function financeSummary({host,transport,context,onOpen}){
 let epoch=0,busy=false;
 const el=(tag,text)=>{const x=document.createElement(tag);if(text!==undefined)x.textContent=text;return x;},money=v=>Number.isSafeInteger(v)?(v/100).toLocaleString('en-US',{style:'currency',currency:'USD'}):'Needs confirmation';
 function button(text,fn){const b=el('button',text);b.type='button';b.className='btn';b.onclick=fn;return b;}
 function base(){host.replaceChildren(el('h2','Current Finance · Parent summary'),el('p','Saved household paycheck plans, separate from your original historical charts. Cash figures still rely on the snapshot date and inputs a parent supplied.'));}
 async function load(){if(busy)return;const generation=epoch;if(context().role!=='adult'){host.replaceChildren();return;}busy=true;base();host.append(el('p','Checking the latest saved plan…'));try{
  const {plans}=await transport('load',{});if(generation!==epoch)return;const latest=[...plans].sort((a,b)=>String(b.updated_at||b.created_at||'').localeCompare(String(a.updated_at||a.created_at||'')))[0];
  base();if(!latest){host.append(el('p','No paycheck plan saved yet. Review current facts and enter a usable cash snapshot before creating a draft.'),button('Open Finance review',()=>onOpen(null)));return;}
  host.append(el('h3',latest.inputs?.name||'Latest paycheck plan'),el('p','Saved '+latest.status+' · revision '+latest.version));
  let current;try{current=await transport('preview',{inputs:latest.inputs});}catch{if(generation!==epoch)return;host.append(el('p','Current calculation could not be checked. Open Finance and preview before relying on this saved plan.'));}
  if(generation!==epoch)return;
  if(current){const changed=latest.source_fingerprint!==current.source_fingerprint,blocked=!Array.isArray(current.blockers)||current.blockers.length>0;host.append(el('strong',changed?'Sources changed · re-review required':blocked?'Needs confirmation · review required':latest.status==='approved'?'Saved approval · current source check passed':'Draft · not approved'));
   if(changed||blocked){host.append(el('p','Amounts are hidden here until the current plan is reviewed. A prior approval does not approve changed facts.'));if(Array.isArray(current.blockers)){const list=el('ul');for(const text of current.blockers)list.append(el('li',text));host.append(list);}}
   else{host.append(el('p','Current recalculation of saved inputs · '+current.window_start+' to '+current.window_end+' · Cash snapshot '+current.cash_as_of));const list=el('dl');for(const[label,value]of [['Entered usable cash',current.cash_cents],['Bills and debt minimums',current.required_cents],['Living remaining',current.living_cents],['Buffer and other protection',Number.isSafeInteger(current.buffer_cents)&&Number.isSafeInteger(current.protected_cents)?current.buffer_cents+current.protected_cents:null],['Optional allocations',current.optional_cents],['Unassigned',current.unassigned_cents]])list.append(el('dt',label),el('dd',money(value)));host.append(list);}
  }
  host.append(el('p','Checked '+new Date().toLocaleString('en-US',{timeZone:'America/New_York',hour12:true})+' Eastern. This is not a bank balance check and no payment is sent.'),button('Review latest paycheck plan',()=>onOpen(latest.id)));
 }catch{if(generation===epoch){base();host.append(el('p','Finance summary could not be loaded. Open Finance to refresh.'),button('Open Finance review',()=>onOpen(null)));}}
 finally{if(generation===epoch){busy=false;host.append(button('Refresh Finance summary',()=>load()));}}}
 return{load,clear(){epoch++;busy=false;host.replaceChildren();}};
}
