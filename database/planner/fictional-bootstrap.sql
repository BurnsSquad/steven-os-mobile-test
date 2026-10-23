-- PROPOSAL ONLY: separate administrator approval before execution in isolated sandbox.
-- Reuses existing fictional Auth users; never creates users or alters bb_test_* memberships.
BEGIN;
DO $$ BEGIN
 IF current_user<>'postgres' OR current_setting('bb_planner.approved_bootstrap',true) IS DISTINCT FROM 'fictional-v1' THEN
  RAISE EXCEPTION 'Explicit fictional-v1 administrator opt-in required';
 END IF;
 IF (SELECT count(*) FROM auth.users WHERE id IN (
 '6fe4e705-a92f-44ea-9898-d0eebf1f95d5','fd9810b3-6190-4587-b33c-81de6564a5dc','bb0bed90-1037-419f-a385-90e543575864'))<>3 THEN
  RAISE EXCEPTION 'Expected existing fictional identities missing';
 END IF;
END $$;
INSERT INTO public.bb_planner_households(id,label)
VALUES('bba90000-0000-4000-8000-000000000001','Fictional planner verification');
INSERT INTO public.bb_planner_members(household_id,user_id,member_role) VALUES
('bba90000-0000-4000-8000-000000000001','6fe4e705-a92f-44ea-9898-d0eebf1f95d5','adult'),
('bba90000-0000-4000-8000-000000000001','fd9810b3-6190-4587-b33c-81de6564a5dc','child'),
('bba90000-0000-4000-8000-000000000001','bb0bed90-1037-419f-a385-90e543575864','child');
COMMIT;
