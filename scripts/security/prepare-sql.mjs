// Generates proposals only; this program has no database connection or network calls.
import {readFileSync} from 'node:fs';
import {identities,fixtures,household,tables,emails,ref,ensure,validateSnapshot,digest} from './config.mjs';
export const quote=x=>"'"+String(x).replaceAll("'","''")+"'";
const json=x=>quote(JSON.stringify(x))+'::jsonb';
export function snapshotSQL(ids){const f=fixtures(ids);return `SELECT jsonb_build_object(
 'project_ref', '${ref}', -- Literal target assertion, NOT database-derived identity.
 'execution_role', current_user,
 'captured_at', now(),
 'auth_count', (SELECT count(*) FROM auth.users),
 'private_count', (SELECT count(*) FROM public.bb_test_private_tasks),
 'member_count', (SELECT count(*) FROM public.bb_test_household_members),
 'shared_count', (SELECT count(*) FROM public.bb_test_shared_tasks),
 'public_table_count', (SELECT count(*) FROM pg_tables WHERE schemaname='public'),
 'auth', (SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'email',email) ORDER BY id),'[]'::jsonb) FROM auth.users WHERE email IN (${Object.values(emails).map(quote).join(',')})),
 'private', (SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY id),'[]'::jsonb) FROM public.bb_test_private_tasks t WHERE id IN (${f.private.map(r=>quote(r.id)).join(',')})),
 'members', (SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY user_id),'[]'::jsonb) FROM public.bb_test_household_members t WHERE household_id=${quote(household)} AND user_id IN (${[ids.A,ids.B].map(quote).join(',')})),
 'shared', (SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY id),'[]'::jsonb) FROM public.bb_test_shared_tasks t WHERE id IN (${f.shared.map(r=>quote(r.id)).join(',')})),
 'metadata', (SELECT jsonb_agg(jsonb_build_object('table',c.relname,'rls',c.relrowsecurity,'owner',pg_get_userbyid(c.relowner)) ORDER BY c.relname)
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relname IN (${tables.map(quote).join(',')})),
 'policies', (SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY policyname),'[]'::jsonb) FROM pg_policies p WHERE schemaname='public'),
 'privileges', (SELECT jsonb_agg(jsonb_build_object('table',t,'actor',r,'operation',op,'allowed',has_table_privilege(r,'public.'||t,op)) ORDER BY t,r,op)
  FROM unnest(ARRAY[${tables.map(quote).join(',')}]) t
  CROSS JOIN unnest(ARRAY['anon','authenticated']) r
  CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) op),
 'shared_columns', (SELECT jsonb_agg(jsonb_build_object('actor',r,'column',c,'allowed',has_column_privilege(r,'public.bb_test_shared_tasks',c,'UPDATE')) ORDER BY r,c)
  FROM unnest(ARRAY['anon','authenticated']) r
  CROSS JOIN unnest(ARRAY['id','household_id','created_by','title','completed','created_at']) c)
) AS snapshot;`;}
export function setupSQL(ids){
 const f=fixtures(ids);
 const insert=(table,rows)=>{const cols=Object.keys(rows[0]);return `INSERT INTO public.${table} (${cols.join(',')}) VALUES\n`+rows.map(row=>'('+cols.map(k=>typeof row[k]==='boolean'?String(row[k]):quote(row[k])).join(',')+')').join(',\n')+';';};
 const expectedAuth=Object.entries(ids).map(([a,id])=>({id,email:emails[a]}));
 return `-- PROPOSAL ONLY. Target ${ref}. Review before executing this entire transaction.
-- Creates ONLY sandbox policies/grants, 2 private baselines, 2 memberships and 4 shared fixtures.
BEGIN;
DO $guard$
BEGIN
 IF current_user <> 'postgres' THEN RAISE EXCEPTION 'Unexpected role'; END IF;
 IF (SELECT count(*) FROM pg_tables WHERE schemaname='public')<>3 THEN RAISE EXCEPTION 'Unexpected public tables'; END IF;
 IF (SELECT count(*) FROM public.bb_test_private_tasks)<>0
 OR (SELECT count(*) FROM public.bb_test_household_members)<>0
 OR (SELECT count(*) FROM public.bb_test_shared_tasks)<>0 THEN RAISE EXCEPTION 'Tables not empty'; END IF;
 IF EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public') THEN RAISE EXCEPTION 'Policies already exist'; END IF;
 IF (SELECT count(*) FROM auth.users)<>3
 OR EXISTS(SELECT 1 FROM auth.users u WHERE NOT EXISTS(
  SELECT 1 FROM jsonb_to_recordset(${json(expectedAuth)}) AS e(id uuid,email text)
  WHERE u.id=e.id AND u.email=e.email AND u.email_confirmed_at IS NOT NULL
 )) THEN RAISE EXCEPTION 'Fictional Auth inventory mismatch'; END IF;
END;
$guard$;
ALTER TABLE public.bb_test_private_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_test_household_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_test_shared_tasks ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE public.bb_test_private_tasks,public.bb_test_household_members,public.bb_test_shared_tasks FROM PUBLIC,anon,authenticated;
CREATE POLICY private_select ON public.bb_test_private_tasks FOR SELECT TO authenticated USING (owner_id=(SELECT auth.uid()));
CREATE POLICY private_insert ON public.bb_test_private_tasks FOR INSERT TO authenticated WITH CHECK (owner_id=(SELECT auth.uid()));
CREATE POLICY private_update ON public.bb_test_private_tasks FOR UPDATE TO authenticated USING (owner_id=(SELECT auth.uid())) WITH CHECK (owner_id=(SELECT auth.uid()));
CREATE POLICY private_delete ON public.bb_test_private_tasks FOR DELETE TO authenticated USING (owner_id=(SELECT auth.uid()));
CREATE POLICY member_select ON public.bb_test_household_members FOR SELECT TO authenticated USING (user_id=(SELECT auth.uid()));
CREATE POLICY shared_select ON public.bb_test_shared_tasks FOR SELECT TO authenticated USING (
 EXISTS(SELECT 1 FROM public.bb_test_household_members m WHERE m.household_id=bb_test_shared_tasks.household_id AND m.user_id=(SELECT auth.uid())));
CREATE POLICY shared_insert ON public.bb_test_shared_tasks FOR INSERT TO authenticated WITH CHECK (
 created_by=(SELECT auth.uid()) AND EXISTS(SELECT 1 FROM public.bb_test_household_members m WHERE m.household_id=bb_test_shared_tasks.household_id AND m.user_id=(SELECT auth.uid())));
CREATE POLICY shared_update ON public.bb_test_shared_tasks FOR UPDATE TO authenticated USING (
 EXISTS(SELECT 1 FROM public.bb_test_household_members m WHERE m.household_id=bb_test_shared_tasks.household_id AND m.user_id=(SELECT auth.uid()))) WITH CHECK (
 EXISTS(SELECT 1 FROM public.bb_test_household_members m WHERE m.household_id=bb_test_shared_tasks.household_id AND m.user_id=(SELECT auth.uid())));
GRANT SELECT,INSERT,UPDATE,DELETE ON public.bb_test_private_tasks TO authenticated;
GRANT SELECT ON public.bb_test_household_members TO authenticated;
GRANT SELECT,INSERT ON public.bb_test_shared_tasks TO authenticated;
GRANT UPDATE(title,completed) ON public.bb_test_shared_tasks TO authenticated;
${insert(tables[0],f.private)}
${insert(tables[1],f.members)}
${insert(tables[2],f.shared)}
DO $verify$
BEGIN
 IF (SELECT count(*) FROM public.bb_test_private_tasks)<>2
 OR (SELECT count(*) FROM public.bb_test_household_members)<>2
 OR (SELECT count(*) FROM public.bb_test_shared_tasks)<>4
 OR (SELECT count(*) FROM pg_policies WHERE schemaname='public')<>8 THEN RAISE EXCEPTION 'Setup count mismatch'; END IF;
END;
$verify$;
COMMIT;
-- Independently run snapshot mode next; ordinary tests refuse unexpected grants/state.
`;}
export function cleanupSQL(raw,ids,finalReport){
 const s=validateSnapshot(raw,ids);
 ensure(finalReport?.status==='CLIENT_AND_ADMIN_SNAPSHOTS_MATCH'&&finalReport.project_ref===ref&&finalReport.after_digest===digest(s),'Matching finalized evidence required before cleanup proposal');
 const disposable=s.shared.filter(r=>r.id.startsWith('bba60000-'));
 ensure(disposable.length===3,'Disposable manifest mismatch');
 const baselines={private:s.private,members:s.members,shared:s.shared.filter(r=>!disposable.includes(r)),auth:s.auth};
 const predicate=row=>Object.entries(row).map(([k,v])=>`${k}=${typeof v==='boolean'?String(v):quote(v)}`).join(' AND ');
 const stableChecks=()=>[
  `IF (SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY id),'[]'::jsonb) FROM public.bb_test_private_tasks t)<>${json(baselines.private)} THEN RAISE EXCEPTION 'Private baseline drift'; END IF;`,
  `IF (SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY user_id),'[]'::jsonb) FROM public.bb_test_household_members t)<>${json(baselines.members)} THEN RAISE EXCEPTION 'Membership drift'; END IF;`,
  `IF (SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'email',email) ORDER BY id),'[]'::jsonb) FROM auth.users WHERE email IN (${Object.values(emails).map(quote).join(',')}))<>${json(baselines.auth)} THEN RAISE EXCEPTION 'Auth drift'; END IF;`,
  `IF (SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY id),'[]'::jsonb) FROM public.bb_test_shared_tasks t WHERE id=${quote(baselines.shared[0].id)})<>${json(baselines.shared)} THEN RAISE EXCEPTION 'Shared baseline drift'; END IF;`
 ].join('\n');
 return `-- DESTRUCTIVE PROPOSAL ONLY. Obtain approval of these exact three rows/SQL first.
-- Target ${ref}; never executes from this generator. Requires a verified final snapshot.
BEGIN;
LOCK TABLE public.bb_test_private_tasks,public.bb_test_household_members,public.bb_test_shared_tasks IN ACCESS EXCLUSIVE MODE;
DO $guard$
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'Unexpected role'; END IF;
 IF (SELECT count(*) FROM auth.users)<>3 THEN RAISE EXCEPTION 'Auth count drift'; END IF;
 ${stableChecks()}
 IF (SELECT count(*) FROM public.bb_test_shared_tasks)<>4 THEN RAISE EXCEPTION 'Unexpected shared count'; END IF;
 ${disposable.map(r=>`IF (SELECT count(*) FROM public.bb_test_shared_tasks WHERE ${predicate(r)})<>1 THEN RAISE EXCEPTION 'Fixture mismatch ${r.id}'; END IF;`).join('\n')}
END;
$guard$;
${disposable.map(r=>`DELETE FROM public.bb_test_shared_tasks WHERE ${predicate(r)} RETURNING id,household_id,created_by,title,completed,created_at;`).join('\n')}
DO $verify$
BEGIN
 ${stableChecks()}
 IF (SELECT count(*) FROM public.bb_test_shared_tasks)<>1 THEN RAISE EXCEPTION 'Cleanup count mismatch'; END IF;
END;
$verify$;
COMMIT;
-- Expected DELETE returns: exactly one row per statement, three rows total.
-- Keep both memberships, all Auth identities, private baselines and original shared baseline.
-- Compare metadata/policies/grants before/after independently; they are not changed here.
`;}
if(import.meta.url===new URL(process.argv[1]||'', 'file:').href){
 try{
  const [mode,input,evidence]=process.argv.slice(2);
  ensure(['setup','snapshot','cleanup'].includes(mode),'Use setup, snapshot or cleanup <final-snapshot.json>');
  if(mode==='snapshot') console.log(snapshotSQL(identities()));
  else if(mode==='setup') console.log(setupSQL(identities()));
  else {ensure(input&&evidence,'Final snapshot and finalized report paths required');console.log(cleanupSQL(JSON.parse(readFileSync(input,'utf8')),identities(),JSON.parse(readFileSync(evidence,'utf8'))));}
 }catch(e){console.error('Proposal generation refused. Check mode, protected IDs, input format and finalized evidence. No SQL executed.');process.exitCode=1;}
}
