import {PUBLISHABLE_KEY} from './config.mjs';
import {takeRecoveryLink,createRecoveryClient} from './recovery-api.mjs';
const $=id=>document.getElementById(id),client=createRecoveryClient();let busy=false;
function failure(error){
 if(error.code==='PASSWORD_INPUT')$('reset-status').textContent='Use at least 12 characters and enter the same password twice.';
 else if(error.code==='WEAK_PASSWORD')$('reset-status').textContent='Choose a stronger password and try again.';
 else if(error.code==='RATE_LIMIT')$('reset-status').textContent='Too many requests. Wait before trying again.';
 else if(error.code==='RECOVERY_LINK'){$('reset-panel').hidden=true;client.clear();$('reset-status').textContent='This recovery link is missing, expired or no longer usable. Return to sign-in and request a new link.';}
 else $('reset-status').textContent='The password change could not be confirmed. Check your connection before trying again.';
}
try{const token=takeRecoveryLink(location,history),username=await client.open(token,PUBLISHABLE_KEY);$('reset-heading').textContent=`New password for ${username}`;$('reset-status').textContent='Recovery link verified. Choose a new password below.';$('reset-panel').hidden=false;}catch(error){failure(error);}
$('reset-form').addEventListener('submit',async event=>{event.preventDefault();if(busy)return;busy=true;for(const el of $('reset-form').elements)el.disabled=true;
 const password=$('new-password').value,confirmation=$('confirm-password').value;$('new-password').value='';$('confirm-password').value='';
 try{const result=await client.save(password,confirmation);$('reset-panel').hidden=true;$('reset-status').textContent=result.revocationConfirmed?'Password saved. Return to sign-in and use your username with the new password.':'Password saved. Server session revocation was not confirmed; contact the household organizer. Return to sign-in with your new password.';}catch(error){failure(error);}finally{busy=false;for(const el of $('reset-form').elements)el.disabled=false;}
});
addEventListener('pagehide',()=>client.clear());
