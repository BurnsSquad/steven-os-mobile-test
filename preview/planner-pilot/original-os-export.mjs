// Generates private local recovery files from a single saved workspace snapshot.
const safeJSON=value=>JSON.stringify(value).replace(/</g,'\\u003c');
function parse(storage,key,fallback){try{return JSON.parse(storage[key]??'null')??fallback;}catch{throw new Error('Invalid saved recovery data');}}
export function recoveryFiles(source,workspace,{timestamp=new Date().toISOString(),namespace=crypto.randomUUID()}={}){
 const storage=workspace.storage;if(!storage||typeof source.html!=='string')throw new Error('Missing recovery source');
 const data=parse(storage,'steven-os-v60-data',null);if(!data||!Array.isArray(data.events))throw new Error('Missing saved OS events');
 const backup={...data,version:140,exportedAt:timestamp,householdRoutineV79:parse(storage,'steven-os-household-routines-v79',{rules:[],done:{}}),v60Preferences:parse(storage,'steven-os-v60-prefs',{}),originalOSStorage:{...storage},recoveryInfo:{scope:'Original private Steven OS workspace only; shared planner and current Finance database are not included.',workspaceVersion:workspace.version,sourceHTMLSHA256:source.html_sha256||null,sourceBackupSHA256:source.backup_sha256||null}};
 for(const [field,key] of Object.entries({everydaySpendingBudgetsV84:'steven-os-v84-spending-budgets',morningCheckinsV87:'steven-os-morning-checkins-v87',dailyCoachLibraryV88:'steven-os-daily-coach-library-v88',schoolNotesV95:'steven-os-school-notes-v95',opportunityBoardV96:'steven-os-opportunity-v96',opportunityAssignmentsV100:'steven-os-opportunity-assignments-v100'}))if(Object.hasOwn(storage,key))backup[field]=parse(storage,key,null);backup.layoutTheme=backup.v60Preferences.dark?'dark':'white';
 const json=JSON.stringify(backup,null,2);
 let html=source.html.replace(/<script id="starter"[^>]*>[\s\S]*?<\/script>/,()=>'<script id="starter" type="application/json">'+safeJSON(data)+'</script>');
 html=html.replaceAll('steven-kids-nav-v73','steven-os-kids-nav-v73').replace(/\blocalStorage\b/g,'__recoveryStorage').replace(/\bsessionStorage\b/g,'__recoveryStorage').replace(".concat('burnsBase')",".concat('burnsBase','goalRoadmaps','businessVentures')");
 // Namespace avoids overwriting other original files' browser storage. Memory fallback
 // keeps recovery readable if local-file storage is unavailable.
 const boot=`<script>var __recoveryValues=${safeJSON(storage)},__recoveryPrefix=${safeJSON('steven-os-recovery-'+namespace+'-')};var __recoveryStorage={getItem:k=>{try{const v=window.localStorage.getItem(__recoveryPrefix+k);if(v!==null)return v;}catch(e){}return Object.hasOwn(__recoveryValues,k)?__recoveryValues[k]:null;},setItem:(k,v)=>{__recoveryValues[k]=String(v);try{window.localStorage.setItem(__recoveryPrefix+k,String(v));}catch(e){}}};</script>`;
 html=html.replace(/<head[^>]*>/i,match=>match+boot);
 const note=`<script>document.addEventListener('DOMContentLoaded',()=>{const n=document.createElement('div');n.className='notice';n.textContent=${safeJSON('Offline recovery copy saved '+timestamp+'. Original private OS records only. Shared Tasks/Activities and current Finance database require the online website. Changes here stay local to this copy.')};document.querySelector('.main')?.prepend(n);});</script>`;
 html=html.replace(/<\/body>/i,note+'</body>');
 const parts=Object.fromEntries(new Intl.DateTimeFormat('en-US',{timeZone:'America/New_York',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date(timestamp)).map(p=>[p.type,p.value]));const date=parts.year+'-'+parts.month+'-'+parts.day;return {html:{name:`Steven_OS_Recovery_${date}.html`,type:'text/html',text:html},json:{name:`Steven_OS_Backup_${date}.json`,type:'application/json',text:json}};
}
export function downloadRecoveryFile(file){const url=URL.createObjectURL(new Blob([file.text],{type:file.type}));const a=document.createElement('a');a.href=url;a.download=file.name;a.click();setTimeout(()=>URL.revokeObjectURL(url),15000);}
