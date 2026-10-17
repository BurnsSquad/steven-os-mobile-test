-- Hosted compatibility repair: no new privileges or RLS bypass.
-- Managed Supabase postgres cannot grant USAGE on its auth schema.
-- Reuse auth.uid()'s independently inspected claim extraction in a private invoker.
BEGIN;
DO $$ BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT FROM pg_roles WHERE rolname='bb_planner_executor' AND NOT rolcanlogin AND NOT rolbypassrls AND NOT rolsuper) THEN
  RAISE EXCEPTION 'Verified administrator and restricted planner role required';
 END IF;
END $$;
CREATE OR REPLACE FUNCTION bb_planner_private.actor_uid() RETURNS uuid
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
 SELECT coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),
 (nullif(current_setting('request.jwt.claims',true),'')::jsonb ->> 'sub'))::uuid
$$;
CREATE OR REPLACE FUNCTION bb_planner_private.require_member(h uuid) RETURNS text
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE r text; BEGIN
 IF bb_planner_private.actor_uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 SELECT member_role INTO r FROM public.bb_planner_members WHERE household_id=h AND user_id=bb_planner_private.actor_uid();
 IF r IS NULL THEN RAISE EXCEPTION 'Household access denied' USING ERRCODE='42501'; END IF;
 RETURN r;
END $$;
CREATE OR REPLACE FUNCTION bb_planner_private.check_assignments(h uuid,m text,ids uuid[]) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
BEGIN
 IF m IS NULL OR m NOT IN ('individual','household','shared') OR ids IS NULL OR cardinality(ids)<1 OR cardinality(ids)>100
 OR array_position(ids,NULL) IS NOT NULL OR (m='individual' AND cardinality(ids)<>1)
 OR (SELECT count(DISTINCT x) FROM unnest(ids) x)<>cardinality(ids)
 OR (SELECT count(*) FROM public.bb_planner_members WHERE household_id=h AND user_id=ANY(ids))<>cardinality(ids)
 THEN RAISE EXCEPTION 'Invalid assignment set' USING ERRCODE='22023'; END IF;
END $$;
CREATE OR REPLACE FUNCTION bb_planner_private.item_state(i uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
 SELECT to_jsonb(t) || jsonb_build_object(
  'assignees',(SELECT jsonb_agg(a.assignee_id ORDER BY a.assignee_id) FROM public.bb_planner_assignments a WHERE a.item_id=t.id),
  'completions',COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.contribution_key) FROM public.bb_planner_completions c WHERE c.item_id=t.id),'[]'::jsonb),
  'complete',CASE WHEN t.completion_mode='shared' THEN
    (SELECT count(*) FROM public.bb_planner_assignments a WHERE a.item_id=t.id)=(SELECT count(*) FROM public.bb_planner_completions c WHERE c.item_id=t.id)
    ELSE EXISTS(SELECT FROM public.bb_planner_completions c WHERE c.item_id=t.id) END)
 FROM public.bb_planner_items t WHERE t.id=i
$$;
CREATE OR REPLACE FUNCTION bb_planner_private.create_item(h uuid,i uuid,k text,t text,m text,ids uuid[]) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r text; BEGIN
 r:=bb_planner_private.require_member(h);
 IF k IS NULL OR k NOT IN ('task','activity') OR t IS NULL OR length(btrim(t)) NOT BETWEEN 1 AND 120 OR i IS NULL THEN
  RAISE EXCEPTION 'Invalid item' USING ERRCODE='22023'; END IF;
 IF r='child' AND (k<>'activity' OR m IS DISTINCT FROM 'individual' OR ids IS DISTINCT FROM ARRAY[bb_planner_private.actor_uid()]) THEN
  RAISE EXCEPTION 'Children create self-assigned Activities only' USING ERRCODE='42501'; END IF;
 PERFORM bb_planner_private.check_assignments(h,m,ids);
 INSERT INTO public.bb_planner_items(id,household_id,created_by,item_type,title,completion_mode) VALUES(i,h,bb_planner_private.actor_uid(),k,btrim(t),m);
 INSERT INTO public.bb_planner_assignments(item_id,household_id,assignee_id) SELECT i,h,x FROM unnest(ids) x;
 INSERT INTO public.bb_planner_events(item_id,household_id,actor_id,action) VALUES(i,h,bb_planner_private.actor_uid(),'created');
 RETURN bb_planner_private.item_state(i);
END $$;
CREATE OR REPLACE FUNCTION bb_planner_private.rename_item(i uuid,t text,v bigint) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE row public.bb_planner_items; r text; BEGIN
 SELECT * INTO row FROM public.bb_planner_items WHERE id=i FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Item unavailable' USING ERRCODE='42501'; END IF;
 r:=bb_planner_private.require_member(row.household_id);
 IF r<>'adult' AND NOT(row.item_type='activity' AND row.created_by=bb_planner_private.actor_uid()) THEN RAISE EXCEPTION 'Edit denied' USING ERRCODE='42501'; END IF;
 IF v IS NULL OR row.version<>v THEN RAISE EXCEPTION 'Version conflict' USING ERRCODE='40001'; END IF;
 IF t IS NULL OR length(btrim(t)) NOT BETWEEN 1 AND 120 THEN RAISE EXCEPTION 'Invalid title' USING ERRCODE='22023'; END IF;
 UPDATE public.bb_planner_items SET title=btrim(t),version=version+1,updated_at=clock_timestamp() WHERE id=i;
 INSERT INTO public.bb_planner_events(item_id,household_id,actor_id,action) VALUES(i,row.household_id,bb_planner_private.actor_uid(),'renamed');
 RETURN bb_planner_private.item_state(i);
END $$;
CREATE OR REPLACE FUNCTION bb_planner_private.assign_item(i uuid,m text,ids uuid[],v bigint) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE row public.bb_planner_items; BEGIN
 SELECT * INTO row FROM public.bb_planner_items WHERE id=i FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Item unavailable' USING ERRCODE='42501'; END IF;
 IF bb_planner_private.require_member(row.household_id)<>'adult' THEN RAISE EXCEPTION 'Assignment denied' USING ERRCODE='42501'; END IF;
 IF v IS NULL OR row.version<>v THEN RAISE EXCEPTION 'Version conflict' USING ERRCODE='40001'; END IF;
 IF EXISTS(SELECT FROM public.bb_planner_completions WHERE item_id=i) THEN RAISE EXCEPTION 'Contributions lock reassignment' USING ERRCODE='55000'; END IF;
 PERFORM bb_planner_private.check_assignments(row.household_id,m,ids);
 DELETE FROM public.bb_planner_assignments WHERE item_id=i;
 INSERT INTO public.bb_planner_assignments(item_id,household_id,assignee_id) SELECT i,row.household_id,x FROM unnest(ids) x;
 UPDATE public.bb_planner_items SET completion_mode=m,version=version+1,updated_at=clock_timestamp() WHERE id=i;
 INSERT INTO public.bb_planner_events(item_id,household_id,actor_id,action) VALUES(i,row.household_id,bb_planner_private.actor_uid(),'assigned');
 RETURN bb_planner_private.item_state(i);
END $$;
CREATE OR REPLACE FUNCTION bb_planner_private.complete_item(i uuid,for_member uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE row public.bb_planner_items; r text; target uuid; key text; BEGIN
 SELECT * INTO row FROM public.bb_planner_items WHERE id=i FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Item unavailable' USING ERRCODE='42501'; END IF;
 r:=bb_planner_private.require_member(row.household_id);target:=COALESCE(for_member,bb_planner_private.actor_uid());
 IF r<>'adult' AND target<>bb_planner_private.actor_uid() THEN RAISE EXCEPTION 'Contribution impersonation denied' USING ERRCODE='42501'; END IF;
 IF row.completion_mode='household' THEN
  IF target<>bb_planner_private.actor_uid() THEN RAISE EXCEPTION 'Household completion records actual actor' USING ERRCODE='42501'; END IF;
  key:='household';
 ELSE key:=target::text; END IF;
 IF NOT(row.completion_mode='household' AND r='adult') AND NOT EXISTS(SELECT FROM public.bb_planner_assignments WHERE item_id=i AND assignee_id=target) THEN RAISE EXCEPTION 'Assignee required' USING ERRCODE='42501'; END IF;
 -- Row lock serializes assignment/completion; PK makes repeat requests idempotent.
 IF EXISTS(SELECT FROM public.bb_planner_completions WHERE item_id=i AND contribution_key=key) THEN RETURN bb_planner_private.item_state(i); END IF;
 -- Add an adult's own assignment only for the first accepted household completion.
 IF row.completion_mode='household' AND r='adult' AND NOT EXISTS(SELECT FROM public.bb_planner_assignments WHERE item_id=i AND assignee_id=target) THEN
  INSERT INTO public.bb_planner_assignments(item_id,household_id,assignee_id) VALUES(i,row.household_id,target);
 END IF;
 INSERT INTO public.bb_planner_completions(item_id,household_id,contribution_key,assignee_id,actor_id) VALUES(i,row.household_id,key,target,bb_planner_private.actor_uid());
 INSERT INTO public.bb_planner_events(item_id,household_id,actor_id,action,details) VALUES(i,row.household_id,bb_planner_private.actor_uid(),'completed',jsonb_build_object('member',target));
 UPDATE public.bb_planner_items SET version=version+1,updated_at=clock_timestamp() WHERE id=i;
 RETURN bb_planner_private.item_state(i);
END $$;
CREATE OR REPLACE FUNCTION bb_planner_private.list_items(h uuid) RETURNS SETOF jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM bb_planner_private.require_member(h);
 RETURN QUERY SELECT bb_planner_private.item_state(id) FROM public.bb_planner_items WHERE household_id=h ORDER BY created_at,id;
END $$;
GRANT CREATE ON SCHEMA bb_planner_private TO bb_planner_executor;
ALTER FUNCTION bb_planner_private.actor_uid() OWNER TO bb_planner_executor;
REVOKE CREATE ON SCHEMA bb_planner_private FROM bb_planner_executor;
REVOKE ALL ON FUNCTION bb_planner_private.actor_uid() FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
