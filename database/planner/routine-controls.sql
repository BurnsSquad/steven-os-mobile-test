-- Parent-managed future occurrences; existing items/completions are never rewritten.
ALTER TABLE bb_planner_private.routines ADD COLUMN weekdays integer[] NOT NULL DEFAULT ARRAY[1,2,3,4,5,6,7], ADD COLUMN version bigint NOT NULL DEFAULT 1 CHECK(version>0);
ALTER TABLE bb_planner_private.routine_templates ADD COLUMN enabled boolean NOT NULL DEFAULT true;
CREATE ROLE bb_planner_routine_editor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT bb_planner_routine_editor TO postgres;
GRANT USAGE ON SCHEMA bb_planner_private,public TO bb_planner_routine_editor;
GRANT SELECT ON public.bb_planner_members,bb_planner_private.routines,bb_planner_private.routine_templates TO bb_planner_routine_editor;
GRANT UPDATE(evening_start,weekdays,enabled,version) ON bb_planner_private.routines TO bb_planner_routine_editor;
GRANT INSERT ON bb_planner_private.routine_templates TO bb_planner_routine_editor;
GRANT UPDATE(title,completion_mode,assignee_ids,enabled) ON bb_planner_private.routine_templates TO bb_planner_routine_editor;
CREATE POLICY routine_editor_members ON public.bb_planner_members FOR SELECT TO bb_planner_routine_editor USING(true);
CREATE POLICY routine_editor_read ON bb_planner_private.routines FOR SELECT TO bb_planner_routine_editor USING(true);
CREATE POLICY routine_editor_update ON bb_planner_private.routines FOR UPDATE TO bb_planner_routine_editor USING(true) WITH CHECK(true);
CREATE POLICY routine_template_editor_read ON bb_planner_private.routine_templates FOR SELECT TO bb_planner_routine_editor USING(true);
CREATE POLICY routine_template_editor_insert ON bb_planner_private.routine_templates FOR INSERT TO bb_planner_routine_editor WITH CHECK(true);
CREATE POLICY routine_template_editor_update ON bb_planner_private.routine_templates FOR UPDATE TO bb_planner_routine_editor USING(true) WITH CHECK(true);
GRANT EXECUTE ON FUNCTION bb_planner_private.actor_uid(),bb_planner_private.require_member(uuid),bb_planner_private.check_assignments(uuid,text,uuid[]) TO bb_planner_routine_editor;

CREATE FUNCTION bb_planner_private.routine_state(rid uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
 SELECT jsonb_build_object('id',r.id,'household_id',r.household_id,'timezone',r.timezone,'time',to_char(r.evening_start,'HH24:MI'),'weekdays',r.weekdays,'enabled',r.enabled,'version',r.version,'templates',coalesce((SELECT jsonb_agg(jsonb_build_object('id',t.id,'title',t.title,'mode',t.completion_mode,'assignees',t.assignee_ids,'enabled',t.enabled) ORDER BY t.id) FROM bb_planner_private.routine_templates t WHERE t.routine_id=r.id),'[]'::jsonb)) FROM bb_planner_private.routines r WHERE r.id=rid
$$;
CREATE FUNCTION bb_planner_private.routine_list(h uuid) RETURNS SETOF jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF bb_planner_private.require_member(h)<>'adult' THEN RAISE EXCEPTION 'Adults manage routines' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT bb_planner_private.routine_state(id) FROM bb_planner_private.routines WHERE household_id=h ORDER BY id;
END $$;
CREATE FUNCTION bb_planner_private.routine_save(rid uuid,v bigint,at_time text,days integer[],active boolean) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r bb_planner_private.routines;
BEGIN
 SELECT * INTO r FROM bb_planner_private.routines WHERE id=rid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Routine unavailable' USING ERRCODE='42501'; END IF;
 IF bb_planner_private.require_member(r.household_id)<>'adult' THEN RAISE EXCEPTION 'Adults manage routines' USING ERRCODE='42501'; END IF;
 IF v IS NULL OR r.version<>v THEN RAISE EXCEPTION 'Routine changed elsewhere' USING ERRCODE='40001'; END IF;
 IF at_time IS NULL OR at_time !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' OR active IS NULL OR days IS NULL OR cardinality(days) NOT BETWEEN 1 AND 7 OR array_position(days,NULL) IS NOT NULL OR EXISTS(SELECT FROM unnest(days) n WHERE n NOT BETWEEN 1 AND 7) OR (SELECT count(DISTINCT n) FROM unnest(days) n)<>cardinality(days) THEN RAISE EXCEPTION 'Invalid schedule' USING ERRCODE='22023'; END IF;
 UPDATE bb_planner_private.routines SET evening_start=at_time::time,weekdays=ARRAY(SELECT n FROM unnest(days) n ORDER BY n),enabled=active,version=version+1 WHERE id=rid;
 RETURN bb_planner_private.routine_state(rid);
END $$;
CREATE FUNCTION bb_planner_private.routine_task_save(rid uuid,v bigint,tid uuid,t text,m text,ids uuid[],active boolean) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r bb_planner_private.routines;
BEGIN
 SELECT * INTO r FROM bb_planner_private.routines WHERE id=rid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Routine unavailable' USING ERRCODE='42501'; END IF;
 IF bb_planner_private.require_member(r.household_id)<>'adult' THEN RAISE EXCEPTION 'Adults manage routines' USING ERRCODE='42501'; END IF;
 IF v IS NULL OR r.version<>v THEN RAISE EXCEPTION 'Routine changed elsewhere' USING ERRCODE='40001'; END IF;
 IF t IS NULL OR length(btrim(t)) NOT BETWEEN 1 AND 105 OR active IS NULL THEN RAISE EXCEPTION 'Invalid repeating Task' USING ERRCODE='22023'; END IF;
 PERFORM bb_planner_private.check_assignments(r.household_id,m,ids);
 IF tid IS NULL THEN
  IF (SELECT count(*) FROM bb_planner_private.routine_templates WHERE routine_id=rid)>=30 THEN RAISE EXCEPTION 'Routine limit reached' USING ERRCODE='22023'; END IF;
  INSERT INTO bb_planner_private.routine_templates(routine_id,title,completion_mode,assignee_ids,enabled) VALUES(rid,btrim(t),m,ids,active);
 ELSE
  UPDATE bb_planner_private.routine_templates SET title=btrim(t),completion_mode=m,assignee_ids=ids,enabled=active WHERE id=tid AND routine_id=rid;
  IF NOT FOUND THEN RAISE EXCEPTION 'Task unavailable' USING ERRCODE='42501'; END IF;
 END IF;
 UPDATE bb_planner_private.routines SET version=version+1 WHERE id=rid;
 RETURN bb_planner_private.routine_state(rid);
END $$;
CREATE OR REPLACE FUNCTION bb_planner_private.generate_evening_routines(at_time timestamptz DEFAULT clock_timestamp())
RETURNS integer LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE r record; t record; local_time timestamp; d date; item uuid; generated integer:=0;
BEGIN
 IF current_user <> 'postgres' THEN RAISE EXCEPTION 'Administrator scheduler only' USING ERRCODE='42501'; END IF;
 FOR r IN SELECT * FROM bb_planner_private.routines WHERE enabled ORDER BY id FOR UPDATE LOOP
  local_time:=at_time AT TIME ZONE r.timezone; d:=local_time::date;
  IF d<r.starts_on OR local_time::time<r.evening_start OR NOT(extract(isodow FROM d)::integer=ANY(r.weekdays)) THEN CONTINUE; END IF;
  IF NOT EXISTS(SELECT FROM public.bb_planner_members WHERE household_id=r.household_id AND user_id=r.owner_id AND member_role='adult') THEN
   RAISE EXCEPTION 'Routine owner must remain an adult member';
  END IF;
  FOR t IN SELECT * FROM bb_planner_private.routine_templates WHERE routine_id=r.id AND enabled ORDER BY id LOOP
   IF EXISTS(SELECT FROM bb_planner_private.routine_occurrences WHERE template_id=t.id AND evening_date=d) THEN CONTINUE; END IF;
   PERFORM bb_planner_private.check_assignments(r.household_id,t.completion_mode,t.assignee_ids);
   item:=gen_random_uuid();
   INSERT INTO public.bb_planner_items(id,household_id,created_by,item_type,title,completion_mode)
    VALUES(item,r.household_id,r.owner_id,'task',t.title||' ['||to_char(d,'YYYY-MM-DD')||']',t.completion_mode);
   INSERT INTO public.bb_planner_assignments(item_id,household_id,assignee_id) SELECT item,r.household_id,x FROM unnest(t.assignee_ids) x;
   INSERT INTO public.bb_planner_events(item_id,household_id,actor_id,action,details)
    VALUES(item,r.household_id,r.owner_id,'created',jsonb_build_object('routine',r.routine_key,'evening_date',d,'setup_method','scheduled_on_owner_request','recurs',true));
   INSERT INTO bb_planner_private.routine_occurrences(template_id,evening_date,item_id) VALUES(t.id,d,item);
   generated:=generated+1;
  END LOOP;
 END LOOP;
 RETURN generated;
END $$;

GRANT CREATE ON SCHEMA bb_planner_private TO bb_planner_routine_editor;
ALTER FUNCTION bb_planner_private.routine_state(uuid) OWNER TO bb_planner_routine_editor;
ALTER FUNCTION bb_planner_private.routine_list(uuid) OWNER TO bb_planner_routine_editor;
ALTER FUNCTION bb_planner_private.routine_save(uuid,bigint,text,integer[],boolean) OWNER TO bb_planner_routine_editor;
ALTER FUNCTION bb_planner_private.routine_task_save(uuid,bigint,uuid,text,text,uuid[],boolean) OWNER TO bb_planner_routine_editor;
REVOKE CREATE ON SCHEMA bb_planner_private FROM bb_planner_routine_editor;
REVOKE ALL ON FUNCTION bb_planner_private.routine_state(uuid),bb_planner_private.routine_list(uuid),bb_planner_private.routine_save(uuid,bigint,text,integer[],boolean),bb_planner_private.routine_task_save(uuid,bigint,uuid,text,text,uuid[],boolean) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION bb_planner_private.routine_list(uuid),bb_planner_private.routine_save(uuid,bigint,text,integer[],boolean),bb_planner_private.routine_task_save(uuid,bigint,uuid,text,text,uuid[],boolean) TO authenticated;
CREATE FUNCTION public.bb_planner_routines(h uuid) RETURNS SETOF jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT * FROM bb_planner_private.routine_list(h) $$;
CREATE FUNCTION public.bb_planner_routine_save(rid uuid,v bigint,at_time text,days integer[],active boolean) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.routine_save(rid,v,at_time,days,active) $$;
CREATE FUNCTION public.bb_planner_routine_task_save(rid uuid,v bigint,tid uuid,t text,m text,ids uuid[],active boolean) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.routine_task_save(rid,v,tid,t,m,ids,active) $$;
REVOKE ALL ON FUNCTION public.bb_planner_routines(uuid),public.bb_planner_routine_save(uuid,bigint,text,integer[],boolean),public.bb_planner_routine_task_save(uuid,bigint,uuid,text,text,uuid[],boolean) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.bb_planner_routines(uuid),public.bb_planner_routine_save(uuid,bigint,text,integer[],boolean),public.bb_planner_routine_task_save(uuid,bigint,uuid,text,text,uuid[],boolean) TO authenticated;
-- Minute checks support the exact time chosen by parents, including DST.
SELECT cron.alter_job(job_id:=(SELECT jobid FROM cron.job WHERE jobname='bb-planner-evening-routines-v1'),schedule:='* * * * *');
NOTIFY pgrst,'reload schema';
