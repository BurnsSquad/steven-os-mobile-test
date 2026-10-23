-- Family-visible flexible priorities. Existing private Priority Board records are not imported.
CREATE TABLE public.bb_priorities(
 id uuid PRIMARY KEY,
 household_id uuid NOT NULL,
 owner_id uuid,
 created_by uuid NOT NULL,
 title text NOT NULL CHECK(length(btrim(title)) BETWEEN 1 AND 160),
 duration_minutes integer NOT NULL CHECK(duration_minutes BETWEEN 5 AND 1440),
 category text NOT NULL DEFAULT '' CHECK(length(category)<=60),
 next_action text NOT NULL DEFAULT '' CHECK(length(next_action)<=500),
 requires_home boolean NOT NULL DEFAULT false,
 requires_homework boolean NOT NULL DEFAULT false,
 requires_energy boolean NOT NULL DEFAULT false,
 completed boolean NOT NULL DEFAULT false,
 completed_by uuid,
 completed_at timestamptz,
 is_archived boolean NOT NULL DEFAULT false,
 version bigint NOT NULL DEFAULT 1 CHECK(version>0),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(household_id,owner_id) REFERENCES public.bb_planner_members(household_id,user_id),
 FOREIGN KEY(household_id,created_by) REFERENCES public.bb_planner_members(household_id,user_id),
 FOREIGN KEY(household_id,completed_by) REFERENCES public.bb_planner_members(household_id,user_id),
 CHECK((completed AND completed_by IS NOT NULL AND completed_at IS NOT NULL) OR (NOT completed AND completed_by IS NULL AND completed_at IS NULL))
);
CREATE INDEX priorities_household ON public.bb_priorities(household_id,is_archived,created_at,id);
CREATE INDEX priorities_owner ON public.bb_priorities(household_id,owner_id,is_archived);
CREATE INDEX priorities_creator ON public.bb_priorities(household_id,created_by);
CREATE INDEX priorities_completed_by ON public.bb_priorities(household_id,completed_by);

CREATE TABLE public.bb_priority_preferences(
 household_id uuid NOT NULL,
 user_id uuid NOT NULL,
 household_ready boolean NOT NULL DEFAULT false,
 homework_ready boolean NOT NULL DEFAULT false,
 focus_energy boolean NOT NULL DEFAULT false,
 minutes integer NOT NULL DEFAULT 30 CHECK(minutes IN(15,30,60,90)),
 version bigint NOT NULL DEFAULT 1 CHECK(version>0),
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(household_id,user_id),
 FOREIGN KEY(household_id,user_id) REFERENCES public.bb_planner_members(household_id,user_id)
);

CREATE TABLE bb_planner_private.priority_changes(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 household_id uuid NOT NULL,
 priority_id uuid,
 actor_id uuid NOT NULL,
 action text NOT NULL,
 before_state jsonb,
 after_state jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX priority_changes_target ON bb_planner_private.priority_changes(household_id,priority_id,created_at);

ALTER TABLE public.bb_priorities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_priority_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE bb_planner_private.priority_changes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bb_priorities,public.bb_priority_preferences,bb_planner_private.priority_changes FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.bb_priorities,public.bb_priority_preferences TO authenticated;
CREATE POLICY priority_family_read ON public.bb_priorities FOR SELECT TO authenticated USING(EXISTS(SELECT FROM public.bb_planner_members m WHERE m.household_id=bb_priorities.household_id AND m.user_id=(SELECT auth.uid())));
CREATE POLICY priority_own_preferences_read ON public.bb_priority_preferences FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()) AND EXISTS(SELECT FROM public.bb_planner_members m WHERE m.household_id=bb_priority_preferences.household_id AND m.user_id=(SELECT auth.uid())));

CREATE ROLE bb_priority_writer NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT bb_priority_writer TO postgres;
GRANT USAGE ON SCHEMA public,bb_planner_private TO bb_priority_writer;
GRANT SELECT ON public.bb_planner_members,public.bb_priorities,public.bb_priority_preferences TO bb_priority_writer;
GRANT INSERT ON public.bb_priorities,public.bb_priority_preferences,bb_planner_private.priority_changes TO bb_priority_writer;
GRANT UPDATE(title,duration_minutes,category,next_action,requires_home,requires_homework,requires_energy,completed,completed_by,completed_at,is_archived,version,updated_at) ON public.bb_priorities TO bb_priority_writer;
GRANT UPDATE(household_ready,homework_ready,focus_energy,minutes,version,updated_at) ON public.bb_priority_preferences TO bb_priority_writer;
CREATE POLICY priority_writer_members ON public.bb_planner_members FOR SELECT TO bb_priority_writer USING(true);
CREATE POLICY priority_writer_read ON public.bb_priorities FOR SELECT TO bb_priority_writer USING(true);
CREATE POLICY priority_writer_add ON public.bb_priorities FOR INSERT TO bb_priority_writer WITH CHECK(true);
CREATE POLICY priority_writer_edit ON public.bb_priorities FOR UPDATE TO bb_priority_writer USING(true) WITH CHECK(true);
CREATE POLICY priority_writer_preference_read ON public.bb_priority_preferences FOR SELECT TO bb_priority_writer USING(true);
CREATE POLICY priority_writer_preference_add ON public.bb_priority_preferences FOR INSERT TO bb_priority_writer WITH CHECK(true);
CREATE POLICY priority_writer_preference_edit ON public.bb_priority_preferences FOR UPDATE TO bb_priority_writer USING(true) WITH CHECK(true);
CREATE POLICY priority_writer_audit ON bb_planner_private.priority_changes FOR INSERT TO bb_priority_writer WITH CHECK(true);
GRANT EXECUTE ON FUNCTION bb_planner_private.actor_uid(),bb_planner_private.require_member(uuid) TO bb_priority_writer;

CREATE FUNCTION bb_planner_private.priority_write(h uuid,i uuid,v bigint,op text,p jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=bb_planner_private.actor_uid();actor_role text;old public.bb_priorities;next public.bb_priorities;owner uuid;duration integer;done boolean;
BEGIN
 actor_role:=bb_planner_private.require_member(h);
 IF i IS NULL OR op IS NULL OR op NOT IN('create','edit','complete','archive') OR p IS NULL OR jsonb_typeof(p)<>'object' THEN RAISE EXCEPTION 'Invalid priority command' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('family-priority:'||i::text,0));SELECT * INTO old FROM public.bb_priorities WHERE id=i FOR UPDATE;
 IF old.id IS NOT NULL AND(old.household_id<>h OR (actor_role<>'adult' AND old.owner_id IS DISTINCT FROM actor)) THEN RAISE EXCEPTION 'Priority unavailable for editing' USING ERRCODE='42501';END IF;
 IF op='create' THEN
  IF v IS NOT NULL OR p-ARRAY['owner_id','title','duration_minutes','category','next_action','requires_home','requires_homework','requires_energy']<>'{}'::jsonb THEN RAISE EXCEPTION 'Invalid priority creation' USING ERRCODE='22023';END IF;
  IF p->'owner_id'='null'::jsonb THEN owner:=NULL;ELSIF jsonb_typeof(p->'owner_id')='string' THEN BEGIN owner:=(p->>'owner_id')::uuid;EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'Invalid owner' USING ERRCODE='22023';END;ELSE RAISE EXCEPTION 'Invalid owner' USING ERRCODE='22023';END IF;
  IF (actor_role<>'adult' AND owner IS DISTINCT FROM actor) OR (owner IS NOT NULL AND NOT EXISTS(SELECT FROM public.bb_planner_members WHERE household_id=h AND user_id=owner)) THEN RAISE EXCEPTION 'Owner unavailable' USING ERRCODE='42501';END IF;
 END IF;
 IF op IN('create','edit') THEN
  IF (op='edit' AND p-ARRAY['title','duration_minutes','category','next_action','requires_home','requires_homework','requires_energy']<>'{}'::jsonb)
   OR coalesce(jsonb_typeof(p->'title'),'null')<>'string' OR length(btrim(p->>'title')) NOT BETWEEN 1 AND 160
   OR coalesce(jsonb_typeof(p->'duration_minutes'),'null')<>'number' OR (p->>'duration_minutes')!~'^[0-9]+$'
   OR coalesce(jsonb_typeof(p->'category'),'null')<>'string' OR length(p->>'category')>60
   OR coalesce(jsonb_typeof(p->'next_action'),'null')<>'string' OR length(p->>'next_action')>500
   OR coalesce(jsonb_typeof(p->'requires_home'),'null')<>'boolean' OR coalesce(jsonb_typeof(p->'requires_homework'),'null')<>'boolean' OR coalesce(jsonb_typeof(p->'requires_energy'),'null')<>'boolean'
  THEN RAISE EXCEPTION 'Invalid priority fields' USING ERRCODE='22023';END IF;
  duration:=(p->>'duration_minutes')::integer;IF duration NOT BETWEEN 5 AND 1440 THEN RAISE EXCEPTION 'Invalid duration' USING ERRCODE='22023';END IF;
 ELSIF op='complete' THEN
  IF p-ARRAY['completed']<>'{}'::jsonb OR coalesce(jsonb_typeof(p->'completed'),'null')<>'boolean' THEN RAISE EXCEPTION 'Invalid completion' USING ERRCODE='22023';END IF;done:=(p->>'completed')::boolean;
 ELSIF p<>'{}'::jsonb THEN RAISE EXCEPTION 'Invalid archive payload' USING ERRCODE='22023';END IF;
 IF op='create' THEN
  IF old.id IS NOT NULL THEN
   IF old.created_by=actor AND old.owner_id IS NOT DISTINCT FROM owner AND old.title=btrim(p->>'title') AND old.duration_minutes=duration AND old.category=p->>'category' AND old.next_action=p->>'next_action' AND old.requires_home=(p->>'requires_home')::boolean AND old.requires_homework=(p->>'requires_homework')::boolean AND old.requires_energy=(p->>'requires_energy')::boolean AND NOT old.is_archived THEN RETURN to_jsonb(old);END IF;
   RAISE EXCEPTION 'Priority changed elsewhere' USING ERRCODE='40001';
  END IF;
  INSERT INTO public.bb_priorities(id,household_id,owner_id,created_by,title,duration_minutes,category,next_action,requires_home,requires_homework,requires_energy)
  VALUES(i,h,owner,actor,btrim(p->>'title'),duration,p->>'category',p->>'next_action',(p->>'requires_home')::boolean,(p->>'requires_homework')::boolean,(p->>'requires_energy')::boolean) RETURNING * INTO next;
 ELSE
  IF old.id IS NULL THEN RAISE EXCEPTION 'Priority unavailable' USING ERRCODE='42501';END IF;
  IF v IS NULL OR old.version<>v THEN RAISE EXCEPTION 'Priority changed elsewhere' USING ERRCODE='40001';END IF;
  IF old.is_archived THEN RAISE EXCEPTION 'Archived priority is read-only' USING ERRCODE='55000';END IF;
  IF op='complete' AND old.completed=done THEN RETURN to_jsonb(old);END IF;
  UPDATE public.bb_priorities SET
   title=CASE WHEN op='edit' THEN btrim(p->>'title') ELSE title END,
   duration_minutes=CASE WHEN op='edit' THEN duration ELSE duration_minutes END,
   category=CASE WHEN op='edit' THEN p->>'category' ELSE category END,
   next_action=CASE WHEN op='edit' THEN p->>'next_action' ELSE next_action END,
   requires_home=CASE WHEN op='edit' THEN (p->>'requires_home')::boolean ELSE requires_home END,
   requires_homework=CASE WHEN op='edit' THEN (p->>'requires_homework')::boolean ELSE requires_homework END,
   requires_energy=CASE WHEN op='edit' THEN (p->>'requires_energy')::boolean ELSE requires_energy END,
   completed=CASE WHEN op='complete' THEN done ELSE completed END,
   completed_by=CASE WHEN op='complete' THEN CASE WHEN done THEN actor ELSE NULL END ELSE completed_by END,
   completed_at=CASE WHEN op='complete' THEN CASE WHEN done THEN clock_timestamp() ELSE NULL END ELSE completed_at END,
   is_archived=op='archive',version=version+1,updated_at=clock_timestamp()
  WHERE id=i RETURNING * INTO next;
 END IF;
 INSERT INTO bb_planner_private.priority_changes(household_id,priority_id,actor_id,action,before_state,after_state) VALUES(h,i,actor,op,CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(next));RETURN to_jsonb(next);
END $$;

CREATE FUNCTION bb_planner_private.priority_preference_save(h uuid,v bigint,p jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=bb_planner_private.actor_uid();old public.bb_priority_preferences;next public.bb_priority_preferences;mins integer;
BEGIN
 PERFORM bb_planner_private.require_member(h);
 IF p IS NULL OR jsonb_typeof(p)<>'object' OR p-ARRAY['household_ready','homework_ready','focus_energy','minutes']<>'{}'::jsonb OR coalesce(jsonb_typeof(p->'household_ready'),'null')<>'boolean' OR coalesce(jsonb_typeof(p->'homework_ready'),'null')<>'boolean' OR coalesce(jsonb_typeof(p->'focus_energy'),'null')<>'boolean' OR coalesce(jsonb_typeof(p->'minutes'),'null')<>'number' OR (p->>'minutes')!~'^[0-9]+$' THEN RAISE EXCEPTION 'Invalid readiness settings' USING ERRCODE='22023';END IF;
 mins:=(p->>'minutes')::integer;IF mins NOT IN(15,30,60,90) THEN RAISE EXCEPTION 'Invalid readiness time' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('priority-preference:'||actor::text,0));SELECT * INTO old FROM public.bb_priority_preferences WHERE household_id=h AND user_id=actor FOR UPDATE;
 IF old.user_id IS NULL THEN
  IF v IS NOT NULL THEN RAISE EXCEPTION 'Readiness settings changed elsewhere' USING ERRCODE='40001';END IF;
  INSERT INTO public.bb_priority_preferences(household_id,user_id,household_ready,homework_ready,focus_energy,minutes) VALUES(h,actor,(p->>'household_ready')::boolean,(p->>'homework_ready')::boolean,(p->>'focus_energy')::boolean,mins) RETURNING * INTO next;
 ELSE
  IF v IS NULL OR v<>old.version THEN RAISE EXCEPTION 'Readiness settings changed elsewhere' USING ERRCODE='40001';END IF;
  IF old.household_ready=(p->>'household_ready')::boolean AND old.homework_ready=(p->>'homework_ready')::boolean AND old.focus_energy=(p->>'focus_energy')::boolean AND old.minutes=mins THEN RETURN to_jsonb(old);END IF;
  UPDATE public.bb_priority_preferences SET household_ready=(p->>'household_ready')::boolean,homework_ready=(p->>'homework_ready')::boolean,focus_energy=(p->>'focus_energy')::boolean,minutes=mins,version=version+1,updated_at=clock_timestamp() WHERE household_id=h AND user_id=actor RETURNING * INTO next;
 END IF;
 INSERT INTO bb_planner_private.priority_changes(household_id,priority_id,actor_id,action,before_state,after_state) VALUES(h,NULL,actor,'preference',CASE WHEN old.user_id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(next));RETURN to_jsonb(next);
END $$;

GRANT CREATE ON SCHEMA bb_planner_private TO bb_priority_writer;
ALTER FUNCTION bb_planner_private.priority_write(uuid,uuid,bigint,text,jsonb) OWNER TO bb_priority_writer;
ALTER FUNCTION bb_planner_private.priority_preference_save(uuid,bigint,jsonb) OWNER TO bb_priority_writer;
REVOKE CREATE ON SCHEMA bb_planner_private FROM bb_priority_writer;
REVOKE ALL ON FUNCTION bb_planner_private.priority_write(uuid,uuid,bigint,text,jsonb),bb_planner_private.priority_preference_save(uuid,bigint,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION bb_planner_private.priority_write(uuid,uuid,bigint,text,jsonb),bb_planner_private.priority_preference_save(uuid,bigint,jsonb) TO authenticated;
CREATE FUNCTION public.bb_priority_write(h uuid,i uuid,v bigint,op text,p jsonb) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.priority_write(h,i,v,op,p) $$;
CREATE FUNCTION public.bb_priority_preference_save(h uuid,v bigint,p jsonb) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.priority_preference_save(h,v,p) $$;
REVOKE ALL ON FUNCTION public.bb_priority_write(uuid,uuid,bigint,text,jsonb),public.bb_priority_preference_save(uuid,bigint,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.bb_priority_write(uuid,uuid,bigint,text,jsonb),public.bb_priority_preference_save(uuid,bigint,jsonb) TO authenticated;
