-- Additive administrator-managed recurrence. No identities or templates seeded here.
CREATE TABLE bb_planner_private.routines (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 household_id uuid NOT NULL REFERENCES public.bb_planner_households(id),
 owner_id uuid NOT NULL,
 routine_key text NOT NULL,
 timezone text NOT NULL DEFAULT 'America/New_York' CHECK(timezone='America/New_York'),
 evening_start time NOT NULL DEFAULT '17:00',
 starts_on date NOT NULL,
 enabled boolean NOT NULL DEFAULT true,
 FOREIGN KEY(household_id,owner_id) REFERENCES public.bb_planner_members(household_id,user_id),
 UNIQUE(household_id,routine_key)
);
CREATE TABLE bb_planner_private.routine_templates (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 routine_id uuid NOT NULL REFERENCES bb_planner_private.routines(id),
 title text NOT NULL CHECK(length(btrim(title)) BETWEEN 1 AND 105),
 completion_mode text NOT NULL CHECK(completion_mode IN ('individual','household','shared')),
 assignee_ids uuid[] NOT NULL,
 UNIQUE(id,routine_id)
);
CREATE INDEX routine_templates_routine ON bb_planner_private.routine_templates(routine_id);
CREATE TABLE bb_planner_private.routine_occurrences (
 template_id uuid NOT NULL REFERENCES bb_planner_private.routine_templates(id),
 evening_date date NOT NULL,
 item_id uuid NOT NULL UNIQUE REFERENCES public.bb_planner_items(id),
 PRIMARY KEY(template_id,evening_date)
);
ALTER TABLE bb_planner_private.routines ENABLE ROW LEVEL SECURITY;
ALTER TABLE bb_planner_private.routine_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE bb_planner_private.routine_occurrences ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON bb_planner_private.routines,bb_planner_private.routine_templates,bb_planner_private.routine_occurrences FROM PUBLIC,anon,authenticated,service_role,bb_planner_executor;

-- Invoker, administrator-only. Never accepts browser identity or impersonates JWTs.
-- Timestamp parameter is for rollback-only administrative clock tests.
CREATE FUNCTION bb_planner_private.generate_evening_routines(at_time timestamptz DEFAULT clock_timestamp())
RETURNS integer LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE r record; t record; local_time timestamp; d date; item uuid; generated integer:=0;
BEGIN
 IF current_user <> 'postgres' THEN RAISE EXCEPTION 'Administrator scheduler only' USING ERRCODE='42501'; END IF;
 FOR r IN SELECT * FROM bb_planner_private.routines WHERE enabled ORDER BY id FOR UPDATE LOOP
  local_time:=at_time AT TIME ZONE r.timezone; d:=local_time::date;
  IF d<r.starts_on OR local_time::time<r.evening_start THEN CONTINUE; END IF;
  IF NOT EXISTS(SELECT FROM public.bb_planner_members WHERE household_id=r.household_id AND user_id=r.owner_id AND member_role='adult') THEN
   RAISE EXCEPTION 'Routine owner must remain an adult member';
  END IF;
  FOR t IN SELECT * FROM bb_planner_private.routine_templates WHERE routine_id=r.id ORDER BY id LOOP
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
REVOKE ALL ON FUNCTION bb_planner_private.generate_evening_routines(timestamptz) FROM PUBLIC,anon,authenticated,service_role,bb_planner_executor;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
-- Hourly UTC checks use the household local clock, including daylight saving.
-- Later evening checks retry missed runs without generating duplicate Tasks.
DO $$ BEGIN
 IF EXISTS(SELECT FROM cron.job WHERE jobname='bb-planner-evening-routines-v1') THEN RAISE EXCEPTION 'Scheduler name already exists'; END IF;
END $$;
SELECT cron.schedule('bb-planner-evening-routines-v1','0 * * * *','SELECT bb_planner_private.generate_evening_routines();');
