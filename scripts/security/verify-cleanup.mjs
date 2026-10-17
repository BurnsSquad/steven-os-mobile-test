// Post-cleanup evidence verifier; no network or mutation capability.
import {readFileSync,writeFileSync} from 'node:fs';
import {identities,validateSnapshot,snapshotValue,ensure,canonical,digest,ref} from './config.mjs';
export function verifyCleanup(beforeRaw,afterRaw,finalReport,ids){
 const before=validateSnapshot(beforeRaw,ids),after=snapshotValue(afterRaw);
 ensure(finalReport?.status==='CLIENT_AND_ADMIN_SNAPSHOTS_MATCH'&&finalReport.project_ref===ref&&finalReport.after_digest===digest(before),'Cleanup baseline must match finalized client evidence');
 ensure(after?.shared_count===1&&Array.isArray(after.shared)&&after.shared.length===1,'Unexpected post-cleanup shared count');
 const baseline=before.shared.filter(r=>r.id==='bba30000-0000-4000-8000-000000000001');
 ensure(canonical(after.shared)===canonical(baseline),'Protected shared baseline changed or wrong fixture deleted');
 // Reuse unchanged structure/security checks with original shared manifest supplied only for validation.
 validateSnapshot({...after,shared:before.shared,shared_count:4},ids);
 ensure(Date.parse(after.captured_at)>=Date.parse(before.captured_at),'Cleanup snapshot chronology mismatch');
 for(const key of ['private','members','auth','metadata','policies','privileges','shared_columns'])ensure(canonical(before[key])===canonical(after[key]),`Post-cleanup ${key} drift`);
 return {status:'CLEANUP_AND_FINAL_METADATA_MATCH',project_ref:ref,verified_at:new Date().toISOString(),cleanup_rows:3,shared_baselines_remaining:1,private_baselines_remaining:2,memberships_retained:2,auth_users_retained:3,after_digest:digest(after),provenance:'Operator-attested snapshots; review executed DELETE RETURNING output separately',limitations:finalReport.limitations||[]};
}
if(import.meta.url===new URL(process.argv[1]||'', 'file:').href) try{
 const [beforePath,afterPath,finalPath,out]=process.argv.slice(2);ensure(out,'Four paths required');
 const read=p=>JSON.parse(readFileSync(p,'utf8'));
 const result=verifyCleanup(read(beforePath),read(afterPath),read(finalPath),identities());
 writeFileSync(out,JSON.stringify(result,null,2)+'\n',{flag:'wx',mode:0o600});console.log(result.status);
}catch{console.error('Cleanup NOT VERIFIED. Inspect exact counts, baseline identity, finalized evidence and metadata drift. No SQL executed.');process.exitCode=1;}
