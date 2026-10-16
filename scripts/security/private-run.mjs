// Private local launcher: no password arguments, files, shell history or console echo.
import {spawn} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {resolve,join} from 'node:path';
import {ensure,ref,origin,emails,identities,validateSnapshot} from './config.mjs';
export async function readHidden(label,input=process.stdin,output=process.stdout){
 ensure(input.isTTY&&output.isTTY&&typeof input.setRawMode==='function','Use an interactive Terminal; do not redirect password input');
 output.write(label+': ');
 return new Promise((resolveValue,reject)=>{
  let value='',finished=false;const wasRaw=Boolean(input.isRaw);
  const finish=(error)=>{
   if(finished)return;finished=true;
   input.off('data',onData);input.off('error',onError);input.off('end',onEnd);
   input.setRawMode(wasRaw);input.pause();output.write('\n');
   if(error)reject(error);else resolveValue(value);
  };
  const onError=()=>finish(Error('Private input failed'));
  const onEnd=()=>finish(Error('Private input ended'));
  const onData=chunk=>{
   const text=String(chunk).replace(/\u001b\[20[01]~/g,'');
   for(const char of text){
    if(char==='\u0003')return finish(Error('Cancelled'));
    if(char==='\r'||char==='\n')return finish();
    if(char==='\u007f'||char==='\b'){value=value.slice(0,-1);continue;}
    if(char.codePointAt(0)>=32)value+=char;
    if(value.length>4096)return finish(Error('Private input too long'));
   }
  };
  input.on('data',onData);input.once('error',onError);input.once('end',onEnd);
  input.setRawMode(true);input.resume();
 });
}
export function validateSessionURL(value){
 const url=new URL(value);
 ensure(url.origin==='https://raw.githubusercontent.com'&&!url.search&&!url.hash&&/^\/BurnsSquad\/steven-os-mobile-test\/[0-9a-f]{40}\/docs\/evidence\/sandbox-session\.json$/.test(url.pathname),'Only a pinned review-repository session URL is allowed');
 return url.href;
}
const arg=name=>{const i=process.argv.indexOf(name);return i<0?null:process.argv[i+1];};
async function main(){
 const mode=arg('--mode')||'preflight';ensure(['preflight','update','live'].includes(mode),'Invalid mode');
 ensure(!process.env.BB_TEST_ADMIN_KEY&&!process.env.BB_TEST_OFFLINE_SIMULATION,'Use a clean ordinary-user local process');
 ensure(mode!=='live'||process.argv.includes('--approved-delete-denial'),'Live full suite needs separately approved exact DELETE attempts');
 const url=validateSessionURL(arg('--session-url'));
 const response=await fetch(url,{redirect:'error',signal:AbortSignal.timeout(20000)});
 ensure(response.ok,'Cannot retrieve reviewed session');
 const session=await response.json();
 ensure(session.schema===1&&session.project_ref===ref&&session.policy_reviewed===true,'Session target/review mismatch');
 const ids=Object.fromEntries(Object.entries(emails).map(([actor,email])=>{
  const found=session.snapshot?.auth?.filter(u=>u.email===email);ensure(found?.length===1,'Fictional session identity missing');return [actor,found[0].id];
 }));
 const idEnv=Object.fromEntries(Object.entries(ids).map(([a,id])=>[`BB_TEST_${a}_ID`,id]));
 validateSnapshot(session.snapshot,identities(idEnv),{fresh:true});
 console.log(`Target: Burns Base Security Sandbox (${ref})`);
 console.log(mode==='update'?'UPDATE-only: exact disposable fixtures; no POST/DELETE tests or cleanup.':mode==='preflight'?'Preflight: ordinary sign-in and table reads; no test-table writes.':'Full client suite including separately approved disposable-row DELETE-denial attempts; no cleanup.');
 console.log('Inputs below are hidden. Nothing you type at these prompts is saved in shell history or report files. Ctrl+C cancels.');
 const key=await readHidden('Sandbox public publishable key (sb_publishable_)');
 ensure(key.startsWith('sb_publishable_'),'Expected a public publishable key, never an admin secret');
 const passwords={};
 for(const actor of ['A','B','C']){
  const password=await readHidden(`Saved fictional ${actor} password`);
  ensure(password.length>=24,'Test password must have at least 24 characters');passwords[`BB_TEST_${actor}_PASSWORD`]=password;
 }
 ensure(new Set(Object.values(passwords)).size===3,'Test passwords must be distinct');
 // Refuse expired evidence again after private input, before any sign-in or write.
 validateSnapshot(session.snapshot,identities(idEnv),{fresh:true});
 const root=fileURLToPath(new URL('../../',import.meta.url));
 const runDir=resolve(root,'work','security',new Date().toISOString().replaceAll(':','-'));
 mkdirSync(runDir,{recursive:true,mode:0o700});
 const before=join(runDir,'before.json'),out=join(runDir,'client-report.json');
 writeFileSync(before,JSON.stringify(session.snapshot,null,2)+'\n',{flag:'wx',mode:0o600});
 const env={...process.env,...idEnv,...passwords,BB_TEST_URL:origin,BB_TEST_PUBLISHABLE_KEY:key,BB_TEST_POLICY_REVIEW:ref,BB_TEST_SNAPSHOT_ATTESTATION:ref};
 if(mode==='update'||mode==='live')env.BB_TEST_UPDATE_APPROVAL=ref;
 // Prevent an inherited variable from silently approving deletion in UPDATE-only mode.
 delete env.BB_TEST_DELETE_DENIAL_APPROVAL;
 if(mode==='live')env.BB_TEST_DELETE_DENIAL_APPROVAL=ref;
 const child=spawn(process.execPath,[join(root,'scripts/security/run.mjs'),'--mode',mode,'--before',before,'--out',out],{cwd:root,env,stdio:'inherit'});
 const exit=await new Promise(resolveExit=>{child.once('error',()=>resolveExit(1));child.once('close',code=>resolveExit(code??1));});
 for(const name of Object.keys(passwords)){delete env[name];passwords[name]='';}
 delete env.BB_TEST_PUBLISHABLE_KEY;
 console.log(`Evidence folder: ${runDir}`);
 console.log('Return the credential-free client-report.json for independent administrator verification. No cleanup was run.');
 process.exitCode=exit;
}
if(import.meta.url===new URL(process.argv[1]||'','file:').href)main().catch(()=>{
 console.error('Local session stopped. Check fresh reviewed session URL, ordinary credentials and output status. Raw errors omitted; do not send passwords.');process.exitCode=1;
});
