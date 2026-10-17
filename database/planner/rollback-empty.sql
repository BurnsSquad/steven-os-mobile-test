-- DESTRUCTIVE PROPOSAL ONLY. Separate explicit approval required after commit.
-- Works only when ALL six new tables are empty. Never deletes fixture rows.
BEGIN;
DO $$ BEGIN
 IF current_user<>'postgres' OR current_setting('bb_planner.approved_rollback',true) IS DISTINCT FROM 'empty-planner-v1' THEN
  RAISE EXCEPTION 'Explicit empty-planner-v1 administrator approval required';
 END IF;
 IF EXISTS(SELECT FROM public.bb_planner_households) OR EXISTS(SELECT FROM public.bb_planner_members)
 OR EXISTS(SELECT FROM public.bb_planner_items) OR EXISTS(SELECT FROM public.bb_planner_assignments)
 OR EXISTS(SELECT FROM public.bb_planner_completions) OR EXISTS(SELECT FROM public.bb_planner_events) THEN
  RAISE EXCEPTION 'Planner contains data; separate reviewed recovery/cleanup required';
 END IF;
END $$;
DROP FUNCTION public.bb_planner_list(uuid),public.bb_planner_complete(uuid,uuid),
public.bb_planner_assign(uuid,text,uuid[],bigint),public.bb_planner_rename(uuid,text,bigint),
public.bb_planner_create(uuid,uuid,text,text,text,uuid[]);
DROP FUNCTION bb_planner_private.list_items(uuid),bb_planner_private.complete_item(uuid,uuid),
bb_planner_private.assign_item(uuid,text,uuid[],bigint),bb_planner_private.rename_item(uuid,text,bigint),
bb_planner_private.create_item(uuid,uuid,text,text,text,uuid[]),bb_planner_private.item_state(uuid),
bb_planner_private.check_assignments(uuid,text,uuid[]),bb_planner_private.require_member(uuid);
DROP TABLE public.bb_planner_events,public.bb_planner_completions;
DROP TABLE public.bb_planner_assignments;
DROP TABLE public.bb_planner_items;
DROP POLICY planner_household_read ON public.bb_planner_households;
DROP TABLE public.bb_planner_members;
DROP TABLE public.bb_planner_households;
DROP SCHEMA bb_planner_private;
REVOKE EXECUTE ON FUNCTION auth.uid() FROM bb_planner_executor;
REVOKE USAGE ON SCHEMA public,auth FROM bb_planner_executor;
REVOKE bb_planner_executor FROM postgres;
DROP ROLE bb_planner_executor;
COMMIT;
