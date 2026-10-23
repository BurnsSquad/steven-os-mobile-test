-- Read-only metadata; no credentials or row titles. Run in verified isolated project.
SELECT current_database(),current_user,version();
SELECT c.relname,c.relrowsecurity,pg_get_userbyid(c.relowner) AS owner
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind='r'
AND c.relname IN ('bb_test_private_tasks','bb_test_household_members','bb_test_shared_tasks',
'bb_planner_households','bb_planner_members','bb_planner_items','bb_planner_assignments','bb_planner_completions','bb_planner_events') ORDER BY c.relname;
SELECT schemaname,tablename,policyname,roles,cmd,qual,with_check FROM pg_policies
WHERE schemaname='public' AND (tablename LIKE 'bb_test_%' OR tablename LIKE 'bb_planner_%')
ORDER BY tablename,policyname;
SELECT n.nspname,p.proname,p.prosecdef,pg_get_userbyid(p.proowner) AS owner,p.proconfig,p.proacl
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='bb_planner_private' OR (n.nspname='public' AND p.proname LIKE 'bb_planner_%')
ORDER BY n.nspname,p.proname;
SELECT rolname,rolcanlogin,rolsuper,rolbypassrls FROM pg_roles WHERE rolname='bb_planner_executor';
