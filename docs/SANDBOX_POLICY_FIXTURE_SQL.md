# Sandbox policy and fictional fixture setup

Target only: Burns Base Security Sandbox (`wozynsftofkjqwlflosv`). Prepared 2026-10-16 after independently verifying three confirmed fictional Auth users and empty test tables. The SQL below implements the reviewed runbook scope. It resolves generated Auth UUIDs by exact fictional email at execution time; only intentional fictional fixture UUIDs are fixed. This is not production DDL. Execution and verification outcomes are recorded in the development log; this file alone is not evidence of success.

No shared DELETE permission is granted. C gets no membership. No users are edited, deleted or invited. On any pre-commit error, roll back and inspect. After commit, reversal requires exact reviewed cleanup; SQL ROLLBACK cannot undo an earlier commit. Never rerun this against a populated sandbox, or use production.

```sql
BEGIN;
DO $guard$
BEGIN
 IF current_user <> 'postgres' THEN RAISE EXCEPTION 'Unexpected execution role'; END IF;
 IF (SELECT count(*) FROM pg_tables WHERE schemaname='public')<>3 THEN RAISE EXCEPTION 'Unexpected public tables'; END IF;
 IF EXISTS(SELECT 1 FROM public.bb_test_private_tasks)
 OR EXISTS(SELECT 1 FROM public.bb_test_household_members)
 OR EXISTS(SELECT 1 FROM public.bb_test_shared_tasks) THEN RAISE EXCEPTION 'Test tables are not empty'; END IF;
 IF EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public') THEN RAISE EXCEPTION 'Policies already exist'; END IF;
 IF (SELECT count(*) FROM auth.users)<>3 OR
 (SELECT count(*) FROM auth.users WHERE email IN ('burns-security-a@example.test','burns-security-b@example.test','burns-security-c@example.test') AND email_confirmed_at IS NOT NULL)<>3
 THEN RAISE EXCEPTION 'Fictional Auth inventory mismatch'; END IF;
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

INSERT INTO public.bb_test_private_tasks(id,owner_id,title,completed)
SELECT v.id::uuid,u.id,v.title,false
FROM (VALUES
 ('bba10000-0000-4000-8000-000000000001','burns-security-a@example.test','TEST ONLY - Organize fictional workspace'),
 ('bba10000-0000-4000-8000-000000000002','burns-security-b@example.test','TEST ONLY - Plan fictional family activity')
) AS v(id,email,title) JOIN auth.users u ON u.email=v.email;

INSERT INTO public.bb_test_household_members(household_id,user_id,role)
SELECT 'bba20000-0000-4000-8000-000000000001'::uuid,u.id,v.role
FROM (VALUES ('burns-security-a@example.test','owner'),('burns-security-b@example.test','member')) AS v(email,role)
JOIN auth.users u ON u.email=v.email;

INSERT INTO public.bb_test_shared_tasks(id,household_id,created_by,title,completed)
SELECT v.id::uuid,v.household_id::uuid,u.id,v.title,false
FROM (VALUES
 ('bba30000-0000-4000-8000-000000000001','bba20000-0000-4000-8000-000000000001','burns-security-a@example.test','TEST ONLY - Organize fictional family game night'),
 ('bba60000-0000-4000-8000-000000000001','bba20000-0000-4000-8000-000000000001','burns-security-a@example.test','TEST ONLY - A fictional shared UPDATE check'),
 ('bba60000-0000-4000-8000-000000000002','bba20000-0000-4000-8000-000000000001','burns-security-b@example.test','TEST ONLY - B fictional shared UPDATE check'),
 ('bba60000-0000-4000-8000-000000000099','bba20000-0000-4000-8000-000000000099','burns-security-a@example.test','TEST ONLY - Unrelated household UPDATE target')
) AS v(id,household_id,email,title) JOIN auth.users u ON u.email=v.email;

DO $verify$
BEGIN
 IF (SELECT count(*) FROM public.bb_test_private_tasks)<>2
 OR (SELECT count(*) FROM public.bb_test_household_members)<>2
 OR (SELECT count(*) FROM public.bb_test_shared_tasks)<>4
 OR (SELECT count(*) FROM pg_policies WHERE schemaname='public')<>8 THEN RAISE EXCEPTION 'Post-setup count mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM public.bb_test_household_members m JOIN auth.users u ON u.id=m.user_id WHERE u.email='burns-security-c@example.test')
 THEN RAISE EXCEPTION 'C must remain unrelated'; END IF;
 IF has_table_privilege('authenticated','public.bb_test_shared_tasks','DELETE')
 OR has_table_privilege('authenticated','public.bb_test_shared_tasks','UPDATE')
 OR has_column_privilege('authenticated','public.bb_test_shared_tasks','created_by','UPDATE')
 OR has_column_privilege('authenticated','public.bb_test_shared_tasks','household_id','UPDATE')
 OR NOT has_column_privilege('authenticated','public.bb_test_shared_tasks','title','UPDATE')
 OR NOT has_column_privilege('authenticated','public.bb_test_shared_tasks','completed','UPDATE')
 THEN RAISE EXCEPTION 'Shared grant mismatch'; END IF;
END;
$verify$;
COMMIT;
```
