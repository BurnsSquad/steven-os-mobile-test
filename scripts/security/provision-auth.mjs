// Administrative setup only. Never used by the ordinary authenticated test runner.
import {ensure,origin,emails,ref,request,uuid} from './config.mjs';
async function main(){
 ensure(process.argv.slice(2).join(' ')==='--create-fictional-users','Explicit fictional-account creation flag required');
 ensure(!process.env.CI,'Administrative credentials are prohibited in CI');
 ensure(process.env.BB_TEST_URL===origin&&process.env.BB_TEST_AUTH_APPROVAL===ref,'Sandbox/creation approval guard missing');
 const key=process.env.BB_TEST_ADMIN_KEY;
 ensure(key?.startsWith('sb_secret_'),'Protected sandbox admin secret required');
 const passwords=Object.keys(emails).map(a=>process.env[`BB_TEST_${a}_PASSWORD`]);
 ensure(passwords.every(p=>typeof p==='string'&&p.length>=24),'Three protected test passwords of at least 24 characters required');
 ensure(new Set(passwords).size===3,'Test passwords must be unique');
 const existing=await request('/auth/v1/admin/users?page=1&per_page=100',{key});
 ensure(existing.status===200&&Array.isArray(existing.body?.users),'Cannot verify empty Auth state');
 ensure(existing.body.users.length===0,'Auth is not empty; stop without creating or deleting users');
 for(const [index,actor] of Object.keys(emails).entries()){
  const r=await request('/auth/v1/admin/users',{key,method:'POST',body:{email:emails[actor],password:passwords[index],email_confirm:true,user_metadata:{purpose:'Burns Base fictional security testing'}}});
  ensure(r.status===200||r.status===201,`Auth creation stopped at ${actor}; HTTP ${r.status}. Inspect exact state; do not rerun or delete`);
  ensure(uuid.test(r.body?.id||'')&&r.body?.email===emails[actor],`Auth response mismatch at ${actor}; inspect state`);
  console.log(JSON.stringify({actor,id:r.body.id}));
 }
 console.log('Created three fictional confirmed identities. No invitations sent; passwords/tokens omitted. Configure returned IDs as protected runtime variables.');
}
main().catch(e=>{console.error(e.message.startsWith('fetch')?'Network failure; inspect Auth state before retrying':e.message);process.exitCode=1;});
