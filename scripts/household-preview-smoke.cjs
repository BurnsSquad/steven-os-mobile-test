// OFFLINE browser simulation. All Supabase requests intercepted; no database access.
const {chromium}=require('playwright');
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve('preview/household'),ids={a:'6fe4e705-a92f-44ea-9898-d0eebf1f95d5',b:'fd9810b3-6190-4587-b33c-81de6564a5dc',c:'bb0bed90-1037-419f-a385-90e543575864'},house='bba20000-0000-4000-8000-000000000001';
const rows=[{id:'bba30000-0000-4000-8000-000000000001',household_id:house,created_by:ids.a,title:'TEST ONLY - Preserved fictional baseline',completed:false,created_at:new Date().toISOString()}];
let writes=0,deletes=0,errors=[];
const server={close(){}};
(async()=>{const url='https://preview.invalid/';let browser;
try{
 browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
 async function account(actor,mobile=false){const ctx=await browser.newContext({viewport:mobile?{width:390,height:844}:{width:1280,height:900}});
 await ctx.route('**/*',async route=>{const req=route.request(),u=new URL(req.url());if(u.origin===new URL(url).origin){const name=u.pathname==='/'?'index.html':u.pathname.slice(1);if(!['index.html','app.mjs','style.css'].includes(name))return route.fulfill({status:404,body:''});return route.fulfill({status:200,contentType:name.endsWith('html')?'text/html':name.endsWith('mjs')?'text/javascript':'text/css',body:fs.readFileSync(path.join(root,name),'utf8')});}if(u.origin!=='https://wozynsftofkjqwlflosv.supabase.co')return route.abort();
 const method=req.method();let body=null;try{body=req.postDataJSON();}catch{}const a=(req.headers().authorization||'').replace('Bearer MOCK_','');
 const send=(data,status=200)=>route.fulfill({status,headers:{'content-type':'application/json','access-control-allow-origin':new URL(url).origin},body:JSON.stringify(data)});
 if(u.pathname==='/auth/v1/token')return send({access_token:'MOCK_'+actor});
 if(u.pathname==='/auth/v1/user')return send({id:ids[a],email:`burns-security-${a}@example.test`});
 if(u.pathname==='/auth/v1/logout')return send({});
 if(u.pathname.includes('household_members'))return send(a==='c'?[]:[{household_id:house,user_id:ids[a],role:a==='a'?'owner':'member'}]);
 if(u.pathname.includes('shared_tasks')){
 if(method==='GET')return send(a==='c'?[]:rows);
 if(method==='DELETE'){deletes++;return send({code:'42501'},403);}
 if(a==='c')return send({code:'42501'},403);
 if(method==='POST'){writes++;const row={...body,created_at:new Date().toISOString()};rows.push(row);return send([row],201);}
 if(method==='PATCH'){writes++;const row=rows.find(r=>r.id===u.searchParams.get('id')?.slice(3));assert(row?.id.startsWith('bba80000-'));assert.deepEqual(Object.keys(body).sort(),['completed']);Object.assign(row,body);return send([row]);}
 }return send({},404);
 });const page=await ctx.newPage();page.on('pageerror',e=>errors.push(e.message));await page.goto(url);await page.locator('#key').fill('sb_publishable_OFFLINE_UI_ONLY');await page.locator('#account').selectOption(actor);await page.locator('#password').fill('OFFLINE_NOT_A_REAL_PASSWORD');await page.locator('#login button').click();await page.locator('#workspace').waitFor({state:'visible'});await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('ready.')||document.querySelector('#status').textContent.includes('no household membership.'));return {ctx,page};}
 const A=await account('a'),B=await account('b',true),C=await account('c');
 assert.equal(await A.page.locator('#tasks input').isDisabled(),true);
 await A.page.locator('#title').fill('<img src=x onerror=alert(1)> Fictional picnic');await A.page.locator('#create button').click();await A.page.waitForFunction(()=>document.querySelectorAll('#tasks li').length===2);
 await B.page.locator('#refresh').click();await B.page.waitForFunction(()=>document.querySelectorAll('#tasks li').length===2);
 assert.equal(await B.page.locator('#tasks img').count(),0);
 await B.page.locator('#tasks li').nth(1).locator('input').check();await B.page.waitForFunction(()=>document.querySelector('#status').textContent.includes('Shared task saved.'));
 await A.page.locator('#refresh').click();await A.page.waitForFunction(()=>document.querySelectorAll('#tasks li.done').length===1);
 assert.equal(await C.page.locator('#tasks li').count(),0);assert.equal(await C.page.locator('#create').isVisible(),false);
 assert.equal(await B.page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
 assert.equal(await A.page.evaluate(()=>localStorage.length+sessionStorage.length),0);
 await A.page.locator('#signout').click();await A.page.locator('#signin').waitFor({state:'visible'});assert.equal(await A.page.locator('#tasks li').count(),0);
 assert.equal(rows[0].completed,false);assert.equal(deletes,0);assert.equal(writes,2);assert.deepEqual(errors,[]);
 console.log(JSON.stringify({status:'OFFLINE_BROWSER_SMOKE_PASS',contexts:3,viewports:['desktop','390px mobile'],checks:['A creation visible to B','B completion visible to A','C empty and no creation form','baseline checkbox disabled','task text cannot inject HTML','no horizontal mobile overflow','no browser storage writes','sign-out clears list','no DELETE request'],live_supabase_calls:0}));
}finally{if(browser)await browser.close();server.close();}
})().catch(e=>{console.error(e.message);process.exitCode=1;server.close();});
