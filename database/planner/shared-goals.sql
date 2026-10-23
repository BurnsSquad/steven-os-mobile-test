-- New family-visible roadmaps. Existing private goals are not imported.
CREATE TABLE public.bb_goal_roadmaps(id uuid PRIMARY KEY,household_id uuid NOT NULL,owner_id uuid NOT NULL,created_by uuid NOT NULL,title text NOT NULL CHECK(length(btrim(title)) BETWEEN 1 AND 160),description text NOT NULL DEFAULT '' CHECK(length(description)<=2000),milestones jsonb NOT NULL CHECK(jsonb_typeof(milestones)='array' AND jsonb_array_length(milestones)=3),is_archived boolean NOT NULL DEFAULT false,version bigint NOT NULL DEFAULT 1 CHECK(version>0),created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),FOREIGN KEY(household_id,owner_id) REFERENCES public.bb_planner_members(household_id,user_id),FOREIGN KEY(household_id,created_by) REFERENCES public.bb_planner_members(household_id,user_id));
CREATE INDEX goal_roadmaps_household ON public.bb_goal_roadmaps(household_id,is_archived,created_at,id);
CREATE INDEX goal_roadmaps_owner ON public.bb_goal_roadmaps(household_id,owner_id);
CREATE INDEX goal_roadmaps_creator ON public.bb_goal_roadmaps(household_id,created_by);
CREATE TABLE bb_planner_private.goal_changes(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),household_id uuid NOT NULL,goal_id uuid NOT NULL,actor_id uuid NOT NULL,action text NOT NULL,before_state jsonb,after_state jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX goal_changes_target ON bb_planner_private.goal_changes(goal_id,created_at);
ALTER TABLE public.bb_goal_roadmaps ENABLE ROW LEVEL SECURITY;ALTER TABLE bb_planner_private.goal_changes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bb_goal_roadmaps,bb_planner_private.goal_changes FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.bb_goal_roadmaps TO authenticated;
CREATE POLICY goal_family_read ON public.bb_goal_roadmaps FOR SELECT TO authenticated USING(EXISTS(SELECT FROM public.bb_planner_members m WHERE m.household_id=bb_goal_roadmaps.household_id AND m.user_id=(SELECT auth.uid())));
CREATE ROLE bb_goal_writer NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT bb_goal_writer TO postgres;GRANT USAGE ON SCHEMA public,bb_planner_private TO bb_goal_writer;
GRANT SELECT ON public.bb_planner_members,public.bb_goal_roadmaps TO bb_goal_writer;
GRANT INSERT ON public.bb_goal_roadmaps,bb_planner_private.goal_changes TO bb_goal_writer;
GRANT UPDATE(title,description,milestones,is_archived,version,updated_at) ON public.bb_goal_roadmaps TO bb_goal_writer;
CREATE POLICY goal_writer_members ON public.bb_planner_members FOR SELECT TO bb_goal_writer USING(true);
CREATE POLICY goal_writer_read ON public.bb_goal_roadmaps FOR SELECT TO bb_goal_writer USING(true);
CREATE POLICY goal_writer_add ON public.bb_goal_roadmaps FOR INSERT TO bb_goal_writer WITH CHECK(true);
CREATE POLICY goal_writer_edit ON public.bb_goal_roadmaps FOR UPDATE TO bb_goal_writer USING(true) WITH CHECK(true);
CREATE POLICY goal_writer_audit ON bb_planner_private.goal_changes FOR INSERT TO bb_goal_writer WITH CHECK(true);
GRANT EXECUTE ON FUNCTION bb_planner_private.actor_uid(),bb_planner_private.require_member(uuid) TO bb_goal_writer;
CREATE FUNCTION bb_planner_private.goal_write(h uuid,i uuid,v bigint,op text,p jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=bb_planner_private.actor_uid();actor_role text;old public.bb_goal_roadmaps;next public.bb_goal_roadmaps;owner uuid;roadmap jsonb;mi int;si int;block jsonb;step jsonb;done boolean;patch jsonb;
BEGIN
 actor_role:=bb_planner_private.require_member(h);
 IF i IS NULL OR op IS NULL OR op NOT IN('create','edit','milestone','step','archive') OR p IS NULL OR jsonb_typeof(p)<>'object' THEN RAISE EXCEPTION 'Invalid goal command' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('goal-roadmap:'||i::text,0));SELECT * INTO old FROM public.bb_goal_roadmaps WHERE id=i FOR UPDATE;
 IF old.id IS NOT NULL AND(old.household_id<>h OR (actor_role<>'adult' AND old.owner_id<>actor)) THEN RAISE EXCEPTION 'Goal unavailable for editing' USING ERRCODE='42501';END IF;
 IF op='create' THEN
  IF v IS NOT NULL OR p-ARRAY['owner_id','title','description']<>'{}'::jsonb OR coalesce(jsonb_typeof(p->'owner_id'),'null')<>'string' THEN RAISE EXCEPTION 'Invalid goal creation' USING ERRCODE='22023';END IF;
  BEGIN owner:=(p->>'owner_id')::uuid;EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'Invalid owner' USING ERRCODE='22023';END;
  IF (actor_role<>'adult' AND owner<>actor) OR NOT EXISTS(SELECT FROM public.bb_planner_members WHERE household_id=h AND user_id=owner) THEN RAISE EXCEPTION 'Owner unavailable' USING ERRCODE='42501';END IF;
 END IF;
 IF op IN('create','edit') THEN
  IF (op='edit' AND p-ARRAY['title','description']<>'{}'::jsonb) OR coalesce(jsonb_typeof(p->'title'),'null')<>'string' OR length(btrim(p->>'title')) NOT BETWEEN 1 AND 160 OR coalesce(jsonb_typeof(p->'description'),'null')<>'string' OR length(p->>'description')>2000 THEN RAISE EXCEPTION 'Invalid goal text' USING ERRCODE='22023';END IF;
 END IF;
 IF op='create' THEN
  IF old.id IS NOT NULL THEN
   IF old.created_by=actor AND old.owner_id=owner AND old.title=btrim(p->>'title') AND old.description=p->>'description' AND NOT old.is_archived THEN RETURN to_jsonb(old);END IF;
   RAISE EXCEPTION 'Goal already changed' USING ERRCODE='40001';
  END IF;
  SELECT jsonb_agg(jsonb_build_object('title','Milestone '||m,'steps',(SELECT jsonb_agg(jsonb_build_object('title','Step '||s,'done',false,'completed_by',NULL,'completed_at',NULL) ORDER BY s) FROM generate_series(1,4)s)) ORDER BY m) INTO roadmap FROM generate_series(1,3)m;
  INSERT INTO public.bb_goal_roadmaps(id,household_id,owner_id,created_by,title,description,milestones) VALUES(i,h,owner,actor,btrim(p->>'title'),p->>'description',roadmap) RETURNING * INTO next;
 ELSE
  IF old.id IS NULL THEN RAISE EXCEPTION 'Goal unavailable' USING ERRCODE='42501';END IF;
  IF v IS NULL OR old.version<>v THEN RAISE EXCEPTION 'Goal changed elsewhere' USING ERRCODE='40001';END IF;
  IF old.is_archived THEN RAISE EXCEPTION 'Archived goal is read-only' USING ERRCODE='55000';END IF;
  roadmap:=old.milestones;
  IF op IN('milestone','step') THEN
   IF coalesce(jsonb_typeof(p->'milestone'),'null')<>'number' OR (p->>'milestone')!~'^[0-2]$' THEN RAISE EXCEPTION 'Invalid milestone index' USING ERRCODE='22023';END IF;mi:=(p->>'milestone')::int;
   IF op='milestone' THEN
    IF p-ARRAY['milestone','title','steps']<>'{}'::jsonb OR coalesce(jsonb_typeof(p->'title'),'null')<>'string' OR length(btrim(p->>'title')) NOT BETWEEN 1 AND 160 OR coalesce(jsonb_typeof(p->'steps'),'null')<>'array' THEN RAISE EXCEPTION 'Invalid milestone' USING ERRCODE='22023';END IF;
    IF jsonb_array_length(p->'steps')<>4 OR EXISTS(SELECT FROM jsonb_array_elements(p->'steps')s WHERE jsonb_typeof(s)<>'string' OR length(btrim(s#>>'{}')) NOT BETWEEN 1 AND 160) THEN RAISE EXCEPTION 'Four named steps required' USING ERRCODE='22023';END IF;
    roadmap:=jsonb_set(roadmap,ARRAY[mi::text,'title'],to_jsonb(btrim(p->>'title')));
    FOR si IN 0..3 LOOP roadmap:=jsonb_set(roadmap,ARRAY[mi::text,'steps',si::text,'title'],to_jsonb(btrim(p->'steps'->>si)));END LOOP;
   ELSE
    IF p-ARRAY['milestone','step','done']<>'{}'::jsonb OR coalesce(jsonb_typeof(p->'step'),'null')<>'number' OR (p->>'step')!~'^[0-3]$' OR coalesce(jsonb_typeof(p->'done'),'null')<>'boolean' THEN RAISE EXCEPTION 'Invalid step change' USING ERRCODE='22023';END IF;
    si:=(p->>'step')::int;done:=(p->>'done')::boolean;step:=roadmap->mi->'steps'->si;
    IF (step->>'done')::boolean=done THEN RETURN to_jsonb(old);END IF;
    patch:=jsonb_build_object('done',done,'completed_by',CASE WHEN done THEN actor ELSE NULL END,'completed_at',CASE WHEN done THEN clock_timestamp() ELSE NULL END);
    roadmap:=jsonb_set(roadmap,ARRAY[mi::text,'steps',si::text],step||patch);
   END IF;
  ELSIF op='archive' AND p<>'{}'::jsonb THEN RAISE EXCEPTION 'Invalid archive payload' USING ERRCODE='22023';END IF;
  UPDATE public.bb_goal_roadmaps SET title=CASE WHEN op='edit' THEN btrim(p->>'title') ELSE title END,description=CASE WHEN op='edit' THEN p->>'description' ELSE description END,milestones=roadmap,is_archived=op='archive',version=version+1,updated_at=clock_timestamp() WHERE id=i RETURNING * INTO next;
 END IF;
 INSERT INTO bb_planner_private.goal_changes(household_id,goal_id,actor_id,action,before_state,after_state) VALUES(h,i,actor,op,CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(next));RETURN to_jsonb(next);
END $$;
GRANT CREATE ON SCHEMA bb_planner_private TO bb_goal_writer;ALTER FUNCTION bb_planner_private.goal_write(uuid,uuid,bigint,text,jsonb) OWNER TO bb_goal_writer;REVOKE CREATE ON SCHEMA bb_planner_private FROM bb_goal_writer;
REVOKE ALL ON FUNCTION bb_planner_private.goal_write(uuid,uuid,bigint,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION bb_planner_private.goal_write(uuid,uuid,bigint,text,jsonb) TO authenticated;
CREATE FUNCTION public.bb_goal_write(h uuid,i uuid,v bigint,op text,p jsonb) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.goal_write(h,i,v,op,p) $$;
REVOKE ALL ON FUNCTION public.bb_goal_write(uuid,uuid,bigint,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION public.bb_goal_write(uuid,uuid,bigint,text,jsonb) TO authenticated;
