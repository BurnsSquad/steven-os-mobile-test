-- Administrator-driven SQL-role verification, NOT ordinary JWT/PostgREST proof.
-- Only NEW fictional items in one transaction; ROLLBACK retains no test items.
BEGIN;
DO $$ BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT FROM public.bb_planner_households WHERE id='bba90000-0000-4000-8000-000000000001') THEN
  RAISE EXCEPTION 'Verified administrator and fictional planner setup required';
 END IF;
 IF EXISTS(SELECT FROM public.bb_planner_items WHERE id IN (
 'bbaa0000-0000-4000-8000-000000000001','bbaa0000-0000-4000-8000-000000000002',
 'bbaa0000-0000-4000-8000-000000000003','bbaa0000-0000-4000-8000-000000000004')) THEN
  RAISE EXCEPTION 'Smoke UUID collision; no existing item may be tested';
 END IF;
END $$;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='6fe4e705-a92f-44ea-9898-d0eebf1f95d5';
DO $$
DECLARE
 a uuid:='6fe4e705-a92f-44ea-9898-d0eebf1f95d5';
 b uuid:='fd9810b3-6190-4587-b33c-81de6564a5dc';
 c uuid:='bb0bed90-1037-419f-a385-90e543575864';
 h uuid:='bba90000-0000-4000-8000-000000000001';
 individual uuid:='bbaa0000-0000-4000-8000-000000000001';
 household uuid:='bbaa0000-0000-4000-8000-000000000002';
 shared uuid:='bbaa0000-0000-4000-8000-000000000003';
 activity uuid:='bbaa0000-0000-4000-8000-000000000004';
 state jsonb; first_state jsonb;
BEGIN
 IF current_user<>'authenticated' OR auth.uid()<>a THEN RAISE EXCEPTION 'Role simulation failed'; END IF;
 state:=public.bb_planner_create(h,individual,'task','Fictional hosted individual','individual',ARRAY[b]);
 IF state->>'item_type'<>'task' OR state->>'complete'<>'false' THEN RAISE EXCEPTION 'Adult creation failed'; END IF;
 PERFORM public.bb_planner_create(h,household,'task','Fictional hosted household','household',ARRAY[b,c]);
 PERFORM public.bb_planner_create(h,shared,'task','Fictional hosted Shared','shared',ARRAY[b,c]);
 PERFORM set_config('request.jwt.claim.sub',b::text,true);
 BEGIN
  PERFORM public.bb_planner_create(h,activity,'task','Denied fictional child Task','individual',ARRAY[b]);
  RAISE EXCEPTION 'Child Task creation unexpectedly allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 state:=public.bb_planner_create(h,activity,'activity','Fictional hosted Activity','individual',ARRAY[b]);
 IF state->>'created_by'<>b::text THEN RAISE EXCEPTION 'Child Activity creator mismatch'; END IF;
 BEGIN
  UPDATE public.bb_planner_members SET member_role='adult' WHERE household_id=h AND user_id=b;
  RAISE EXCEPTION 'Role promotion unexpectedly allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  UPDATE public.bb_planner_items SET title='Denied direct update' WHERE id=individual;
  RAISE EXCEPTION 'Direct item write unexpectedly allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.bb_planner_assign(individual,'individual',ARRAY[c],1);
  RAISE EXCEPTION 'Child reassignment unexpectedly allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 state:=public.bb_planner_rename(activity,'Fictional renamed Activity',1);
 BEGIN
  PERFORM public.bb_planner_rename(activity,'Stale fictional change',1);
  RAISE EXCEPTION 'Stale revision unexpectedly allowed';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
 first_state:=public.bb_planner_complete(household);
 state:=public.bb_planner_complete(shared);
 IF state->>'complete'<>'false' OR jsonb_array_length(state->'completions')<>1 THEN RAISE EXCEPTION 'Shared partial failed'; END IF;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 BEGIN
  PERFORM public.bb_planner_rename(activity,'Denied sibling edit',2);
  RAISE EXCEPTION 'Sibling edit unexpectedly allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.bb_planner_complete(individual);
  RAISE EXCEPTION 'Sibling individual completion unexpectedly allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.bb_planner_complete(shared,b);
  RAISE EXCEPTION 'Sibling impersonation unexpectedly allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 state:=public.bb_planner_complete(household);
 IF state<>first_state OR state->'completions'->0->>'actor_id'<>b::text THEN RAISE EXCEPTION 'Household first actor/idempotency failed'; END IF;
 state:=public.bb_planner_complete(shared);
 IF state->>'complete'<>'true' OR jsonb_array_length(state->'completions')<>2 THEN RAISE EXCEPTION 'Shared aggregate failed'; END IF;
 first_state:=state;
 state:=public.bb_planner_complete(shared);
 IF state<>first_state THEN RAISE EXCEPTION 'Duplicate Shared contribution mutated state'; END IF;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 state:=public.bb_planner_complete(individual,b);
 IF state->'completions'->0->>'actor_id'<>a::text OR state->'completions'->0->>'assignee_id'<>b::text THEN RAISE EXCEPTION 'Adult on-behalf attribution failed'; END IF;
 BEGIN
  PERFORM public.bb_planner_assign(individual,'individual',ARRAY[c],2);
  RAISE EXCEPTION 'Reassignment after contribution unexpectedly allowed';
 EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000099',true);
 IF EXISTS(SELECT FROM public.bb_planner_items) THEN RAISE EXCEPTION 'Nonmember RLS isolation failed'; END IF;
 BEGIN
  PERFORM public.bb_planner_list(h);
  RAISE EXCEPTION 'Nonmember RPC unexpectedly allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub','',true);
 BEGIN
  PERFORM public.bb_planner_list(h);
  RAISE EXCEPTION 'Missing identity RPC unexpectedly allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
SELECT 'HOSTED_SQL_ROLE_SMOKE_PASS' AS status,
 (SELECT count(*) FROM public.bb_planner_items) AS remaining_items,
 (SELECT count(*) FROM public.bb_planner_events) AS remaining_events;
