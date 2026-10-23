-- Parent-only business projects/tasks. No financial or legacy-record migration.
CREATE TABLE public.bb_business_ventures(id uuid PRIMARY KEY,household_id uuid NOT NULL,created_by uuid NOT NULL,name text NOT NULL CHECK(length(btrim(name)) BETWEEN 1 AND 160),project text NOT NULL CHECK(length(btrim(project)) BETWEEN 1 AND 160),stage text NOT NULL CHECK(stage IN('Planning','Building','Testing','Ready','Operating','Paused')),release_date date,description text NOT NULL DEFAULT '' CHECK(length(description)<=2000),is_archived boolean NOT NULL DEFAULT false,version bigint NOT NULL DEFAULT 1 CHECK(version>0),created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),UNIQUE(household_id,id),FOREIGN KEY(household_id,created_by) REFERENCES public.bb_planner_members(household_id,user_id));
CREATE INDEX business_ventures_household ON public.bb_business_ventures(household_id,is_archived,created_at,id);
CREATE INDEX business_ventures_creator ON public.bb_business_ventures(household_id,created_by);
CREATE TABLE public.bb_business_tasks(id uuid PRIMARY KEY,household_id uuid NOT NULL,venture_id uuid NOT NULL,created_by uuid NOT NULL,title text NOT NULL CHECK(length(btrim(title)) BETWEEN 1 AND 160),project text NOT NULL CHECK(length(btrim(project)) BETWEEN 1 AND 160),department text NOT NULL CHECK(department IN('Strategy','Product & Development','Operations','Marketing','Sales','Finance','Legal & Admin')),due_date date,completed boolean NOT NULL DEFAULT false,completed_by uuid,completed_at timestamptz,is_archived boolean NOT NULL DEFAULT false,version bigint NOT NULL DEFAULT 1 CHECK(version>0),created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),FOREIGN KEY(household_id,venture_id) REFERENCES public.bb_business_ventures(household_id,id),FOREIGN KEY(household_id,created_by) REFERENCES public.bb_planner_members(household_id,user_id),FOREIGN KEY(household_id,completed_by) REFERENCES public.bb_planner_members(household_id,user_id),CHECK((completed AND completed_by IS NOT NULL AND completed_at IS NOT NULL) OR (NOT completed AND completed_by IS NULL AND completed_at IS NULL)));
CREATE INDEX business_tasks_venture ON public.bb_business_tasks(household_id,venture_id,is_archived,created_at,id);
CREATE INDEX business_tasks_creator ON public.bb_business_tasks(household_id,created_by);
CREATE INDEX business_tasks_completer ON public.bb_business_tasks(household_id,completed_by);
CREATE TABLE bb_planner_private.business_changes(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),household_id uuid NOT NULL,target_id uuid NOT NULL,actor_id uuid NOT NULL,action text NOT NULL,before_state jsonb,after_state jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX business_changes_target ON bb_planner_private.business_changes(target_id,created_at);
ALTER TABLE public.bb_business_ventures ENABLE ROW LEVEL SECURITY;ALTER TABLE public.bb_business_tasks ENABLE ROW LEVEL SECURITY;ALTER TABLE bb_planner_private.business_changes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bb_business_ventures,public.bb_business_tasks,bb_planner_private.business_changes FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.bb_business_ventures,public.bb_business_tasks TO authenticated;
CREATE POLICY business_venture_parent_read ON public.bb_business_ventures FOR SELECT TO authenticated USING(EXISTS(SELECT FROM public.bb_planner_members m WHERE m.household_id=bb_business_ventures.household_id AND m.user_id=(SELECT auth.uid()) AND m.member_role='adult'));
CREATE POLICY business_task_parent_read ON public.bb_business_tasks FOR SELECT TO authenticated USING(EXISTS(SELECT FROM public.bb_planner_members m WHERE m.household_id=bb_business_tasks.household_id AND m.user_id=(SELECT auth.uid()) AND m.member_role='adult'));
CREATE ROLE bb_business_writer NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT bb_business_writer TO postgres;GRANT USAGE ON SCHEMA public,bb_planner_private TO bb_business_writer;
GRANT SELECT ON public.bb_planner_members,public.bb_business_ventures,public.bb_business_tasks TO bb_business_writer;
GRANT INSERT ON public.bb_business_ventures,public.bb_business_tasks,bb_planner_private.business_changes TO bb_business_writer;
GRANT UPDATE(name,project,stage,release_date,description,is_archived,version,updated_at) ON public.bb_business_ventures TO bb_business_writer;
GRANT UPDATE(title,project,department,due_date,completed,completed_by,completed_at,is_archived,version,updated_at) ON public.bb_business_tasks TO bb_business_writer;
CREATE POLICY business_writer_members ON public.bb_planner_members FOR SELECT TO bb_business_writer USING(true);
CREATE POLICY business_writer_venture_read ON public.bb_business_ventures FOR SELECT TO bb_business_writer USING(true);
CREATE POLICY business_writer_venture_add ON public.bb_business_ventures FOR INSERT TO bb_business_writer WITH CHECK(true);
CREATE POLICY business_writer_venture_edit ON public.bb_business_ventures FOR UPDATE TO bb_business_writer USING(true) WITH CHECK(true);
CREATE POLICY business_writer_task_read ON public.bb_business_tasks FOR SELECT TO bb_business_writer USING(true);
CREATE POLICY business_writer_task_add ON public.bb_business_tasks FOR INSERT TO bb_business_writer WITH CHECK(true);
CREATE POLICY business_writer_task_edit ON public.bb_business_tasks FOR UPDATE TO bb_business_writer USING(true) WITH CHECK(true);
CREATE POLICY business_writer_audit ON bb_planner_private.business_changes FOR INSERT TO bb_business_writer WITH CHECK(true);
GRANT EXECUTE ON FUNCTION bb_planner_private.actor_uid(),bb_planner_private.require_member(uuid) TO bb_business_writer;
CREATE FUNCTION bb_planner_private.business_venture_save(h uuid,i uuid,v bigint,p jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE old public.bb_business_ventures;next public.bb_business_ventures;actor uuid:=bb_planner_private.actor_uid();release_on date;
BEGIN
 IF bb_planner_private.require_member(h)<>'adult' THEN RAISE EXCEPTION 'Parents only' USING ERRCODE='42501';END IF;
 IF i IS NULL OR p IS NULL OR jsonb_typeof(p)<>'object' OR p-ARRAY['name','project','stage','release_date','description','is_archived']<>'{}'::jsonb OR coalesce(jsonb_typeof(p->'name'),'null')<>'string' OR coalesce(jsonb_typeof(p->'project'),'null')<>'string' OR coalesce(jsonb_typeof(p->'description'),'null')<>'string' OR coalesce(jsonb_typeof(p->'is_archived'),'null')<>'boolean' OR length(btrim(p->>'name')) NOT BETWEEN 1 AND 160 OR length(btrim(p->>'project')) NOT BETWEEN 1 AND 160 OR length(p->>'description')>2000 OR coalesce(p->>'stage','') NOT IN('Planning','Building','Testing','Ready','Operating','Paused') THEN RAISE EXCEPTION 'Invalid venture' USING ERRCODE='22023';END IF;
 BEGIN release_on:=nullif(p->>'release_date','')::date;EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN RAISE EXCEPTION 'Invalid target date' USING ERRCODE='22023';END;
 PERFORM pg_advisory_xact_lock(hashtextextended('business-venture:'||i::text,0));SELECT * INTO old FROM public.bb_business_ventures WHERE id=i FOR UPDATE;
 IF FOUND THEN
  IF old.household_id<>h THEN RAISE EXCEPTION 'Venture unavailable' USING ERRCODE='42501';END IF;
  IF v IS NULL AND old.created_by=actor AND NOT old.is_archived AND old.name=btrim(p->>'name') AND old.project=btrim(p->>'project') AND old.stage=p->>'stage' AND old.release_date IS NOT DISTINCT FROM release_on AND old.description=p->>'description' AND NOT(p->>'is_archived')::boolean THEN RETURN to_jsonb(old);END IF;
  IF v IS NULL OR v<>old.version THEN RAISE EXCEPTION 'Venture changed elsewhere' USING ERRCODE='40001';END IF;
  IF old.is_archived THEN RAISE EXCEPTION 'Archived venture is read-only' USING ERRCODE='55000';END IF;
  UPDATE public.bb_business_ventures SET name=btrim(p->>'name'),project=btrim(p->>'project'),stage=p->>'stage',release_date=release_on,description=p->>'description',is_archived=(p->>'is_archived')::boolean,version=version+1,updated_at=clock_timestamp() WHERE id=i RETURNING * INTO next;
 ELSE
  IF v IS NOT NULL OR (p->>'is_archived')::boolean THEN RAISE EXCEPTION 'Invalid new venture' USING ERRCODE='22023';END IF;
  INSERT INTO public.bb_business_ventures(id,household_id,created_by,name,project,stage,release_date,description) VALUES(i,h,actor,btrim(p->>'name'),btrim(p->>'project'),p->>'stage',release_on,p->>'description') RETURNING * INTO next;
 END IF;
 INSERT INTO bb_planner_private.business_changes(household_id,target_id,actor_id,action,before_state,after_state) VALUES(h,i,actor,'venture_saved',CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(next));RETURN to_jsonb(next);
END $$;
CREATE FUNCTION bb_planner_private.business_task_write(h uuid,b uuid,i uuid,v bigint,op text,p jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE venture public.bb_business_ventures;old public.bb_business_tasks;next public.bb_business_tasks;actor uuid:=bb_planner_private.actor_uid();due_on date;done boolean;
BEGIN
 IF bb_planner_private.require_member(h)<>'adult' THEN RAISE EXCEPTION 'Parents only' USING ERRCODE='42501';END IF;
 IF i IS NULL OR b IS NULL OR p IS NULL OR jsonb_typeof(p)<>'object' OR op IS NULL OR op NOT IN('add','edit','complete','archive') THEN RAISE EXCEPTION 'Invalid business task' USING ERRCODE='22023';END IF;
 IF op IN('add','edit') THEN
  IF p-ARRAY['title','project','department','due_date']<>'{}'::jsonb OR coalesce(jsonb_typeof(p->'title'),'null')<>'string' OR coalesce(jsonb_typeof(p->'project'),'null')<>'string' OR length(btrim(p->>'title')) NOT BETWEEN 1 AND 160 OR length(btrim(p->>'project')) NOT BETWEEN 1 AND 160 OR coalesce(p->>'department','') NOT IN('Strategy','Product & Development','Operations','Marketing','Sales','Finance','Legal & Admin') THEN RAISE EXCEPTION 'Invalid task fields' USING ERRCODE='22023';END IF;
  BEGIN due_on:=nullif(p->>'due_date','')::date;EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN RAISE EXCEPTION 'Invalid due date' USING ERRCODE='22023';END;
 ELSIF op='complete' THEN
  IF p-ARRAY['completed']<>'{}'::jsonb OR coalesce(jsonb_typeof(p->'completed'),'null')<>'boolean' THEN RAISE EXCEPTION 'Invalid completion' USING ERRCODE='22023';END IF;done:=(p->>'completed')::boolean;
 ELSIF p<>'{}'::jsonb THEN RAISE EXCEPTION 'Invalid archive command' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('business-task:'||i::text,0));SELECT * INTO venture FROM public.bb_business_ventures WHERE id=b AND household_id=h FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Venture unavailable' USING ERRCODE='42501';END IF;
 IF venture.is_archived THEN RAISE EXCEPTION 'Archived venture is read-only' USING ERRCODE='55000';END IF;
 SELECT * INTO old FROM public.bb_business_tasks WHERE id=i FOR UPDATE;
 IF op='add' THEN
  IF v IS NOT NULL THEN RAISE EXCEPTION 'Invalid new task' USING ERRCODE='22023';END IF;
  IF FOUND THEN
   IF old.household_id<>h OR old.venture_id<>b OR old.created_by<>actor THEN RAISE EXCEPTION 'Task unavailable' USING ERRCODE='42501';END IF;
   IF NOT old.is_archived AND old.title=btrim(p->>'title') AND old.project=btrim(p->>'project') AND old.department=p->>'department' AND old.due_date IS NOT DISTINCT FROM due_on THEN RETURN to_jsonb(old);END IF;
   RAISE EXCEPTION 'Task changed elsewhere' USING ERRCODE='40001';
  END IF;
  INSERT INTO public.bb_business_tasks(id,household_id,venture_id,created_by,title,project,department,due_date) VALUES(i,h,b,actor,btrim(p->>'title'),btrim(p->>'project'),p->>'department',due_on) RETURNING * INTO next;
 ELSE
  IF old.id IS NULL OR old.household_id<>h OR old.venture_id<>b THEN RAISE EXCEPTION 'Task unavailable' USING ERRCODE='42501';END IF;
  IF v IS NULL OR v<>old.version THEN RAISE EXCEPTION 'Task changed elsewhere' USING ERRCODE='40001';END IF;
  IF old.is_archived THEN RAISE EXCEPTION 'Archived task is read-only' USING ERRCODE='55000';END IF;
  UPDATE public.bb_business_tasks SET title=CASE WHEN op='edit' THEN btrim(p->>'title') ELSE title END,project=CASE WHEN op='edit' THEN btrim(p->>'project') ELSE project END,department=CASE WHEN op='edit' THEN p->>'department' ELSE department END,due_date=CASE WHEN op='edit' THEN due_on ELSE due_date END,completed=CASE WHEN op='complete' THEN done ELSE completed END,completed_by=CASE WHEN op='complete' THEN CASE WHEN done THEN actor ELSE NULL END ELSE completed_by END,completed_at=CASE WHEN op='complete' THEN CASE WHEN done THEN clock_timestamp() ELSE NULL END ELSE completed_at END,is_archived=op='archive',version=version+1,updated_at=clock_timestamp() WHERE id=i RETURNING * INTO next;
 END IF;
 INSERT INTO bb_planner_private.business_changes(household_id,target_id,actor_id,action,before_state,after_state) VALUES(h,i,actor,'task_'||op,CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(next));RETURN to_jsonb(next);
END $$;
GRANT CREATE ON SCHEMA bb_planner_private TO bb_business_writer;
ALTER FUNCTION bb_planner_private.business_venture_save(uuid,uuid,bigint,jsonb) OWNER TO bb_business_writer;ALTER FUNCTION bb_planner_private.business_task_write(uuid,uuid,uuid,bigint,text,jsonb) OWNER TO bb_business_writer;
REVOKE CREATE ON SCHEMA bb_planner_private FROM bb_business_writer;
REVOKE ALL ON FUNCTION bb_planner_private.business_venture_save(uuid,uuid,bigint,jsonb),bb_planner_private.business_task_write(uuid,uuid,uuid,bigint,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION bb_planner_private.business_venture_save(uuid,uuid,bigint,jsonb),bb_planner_private.business_task_write(uuid,uuid,uuid,bigint,text,jsonb) TO authenticated;
CREATE FUNCTION public.bb_business_venture_save(h uuid,i uuid,v bigint,p jsonb) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.business_venture_save(h,i,v,p) $$;
CREATE FUNCTION public.bb_business_task_write(h uuid,b uuid,i uuid,v bigint,op text,p jsonb) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.business_task_write(h,b,i,v,op,p) $$;
REVOKE ALL ON FUNCTION public.bb_business_venture_save(uuid,uuid,bigint,jsonb),public.bb_business_task_write(uuid,uuid,uuid,bigint,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.bb_business_venture_save(uuid,uuid,bigint,jsonb),public.bb_business_task_write(uuid,uuid,uuid,bigint,text,jsonb) TO authenticated;
