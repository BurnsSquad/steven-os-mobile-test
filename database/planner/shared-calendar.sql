-- Additive calendar. Existing private original snapshots are never migrated/shared here.
CREATE TABLE public.bb_calendar_events(id uuid PRIMARY KEY,household_id uuid NOT NULL,created_by uuid NOT NULL,title text NOT NULL CHECK(length(btrim(title)) BETWEEN 1 AND 160),starts_at timestamptz NOT NULL,ends_at timestamptz NOT NULL,all_day boolean NOT NULL DEFAULT false,visibility text NOT NULL CHECK(visibility IN('private','parents','family')),notes text NOT NULL DEFAULT '' CHECK(length(notes)<=2000),status text NOT NULL DEFAULT 'active' CHECK(status IN('active','cancelled')),version bigint NOT NULL DEFAULT 1,created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),FOREIGN KEY(household_id,created_by) REFERENCES public.bb_planner_members(household_id,user_id),CHECK(ends_at>starts_at AND ends_at-starts_at<=interval '367 days'));
CREATE INDEX calendar_household_time ON public.bb_calendar_events(household_id,starts_at,id);
CREATE INDEX calendar_creator ON public.bb_calendar_events(household_id,created_by);
CREATE TABLE bb_planner_private.calendar_changes(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),event_id uuid NOT NULL REFERENCES public.bb_calendar_events(id),household_id uuid NOT NULL,actor_id uuid NOT NULL,action text NOT NULL CHECK(action IN('created','edited','cancelled')),before_state jsonb,after_state jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX calendar_change_event ON bb_planner_private.calendar_changes(event_id,created_at);
ALTER TABLE public.bb_calendar_events ENABLE ROW LEVEL SECURITY;ALTER TABLE bb_planner_private.calendar_changes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bb_calendar_events,bb_planner_private.calendar_changes FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.bb_calendar_events TO authenticated;
CREATE POLICY calendar_member_read ON public.bb_calendar_events FOR SELECT TO authenticated USING(EXISTS(SELECT FROM public.bb_planner_members m WHERE m.household_id=bb_calendar_events.household_id AND m.user_id=(SELECT auth.uid()) AND (bb_calendar_events.created_by=m.user_id OR bb_calendar_events.visibility='family' OR (bb_calendar_events.visibility='parents' AND m.member_role='adult'))));
CREATE ROLE bb_calendar_writer NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT bb_calendar_writer TO postgres;GRANT USAGE ON SCHEMA public,bb_planner_private TO bb_calendar_writer;
GRANT SELECT ON public.bb_planner_members,public.bb_calendar_events TO bb_calendar_writer;
GRANT INSERT ON public.bb_calendar_events,bb_planner_private.calendar_changes TO bb_calendar_writer;
GRANT UPDATE(title,starts_at,ends_at,all_day,visibility,notes,status,version,updated_at) ON public.bb_calendar_events TO bb_calendar_writer;
CREATE POLICY calendar_writer_member ON public.bb_planner_members FOR SELECT TO bb_calendar_writer USING(true);
CREATE POLICY calendar_writer_read ON public.bb_calendar_events FOR SELECT TO bb_calendar_writer USING(true);
CREATE POLICY calendar_writer_insert ON public.bb_calendar_events FOR INSERT TO bb_calendar_writer WITH CHECK(true);
CREATE POLICY calendar_writer_update ON public.bb_calendar_events FOR UPDATE TO bb_calendar_writer USING(true) WITH CHECK(true);
CREATE POLICY calendar_writer_history ON bb_planner_private.calendar_changes FOR INSERT TO bb_calendar_writer WITH CHECK(true);
GRANT EXECUTE ON FUNCTION bb_planner_private.actor_uid(),bb_planner_private.require_member(uuid) TO bb_calendar_writer;
CREATE FUNCTION bb_planner_private.calendar_save(h uuid,i uuid,v bigint,t text,b timestamptz,e timestamptz,full_day boolean,scope text,n text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r text; old public.bb_calendar_events; next public.bb_calendar_events; actor uuid:=bb_planner_private.actor_uid();
BEGIN
 r:=bb_planner_private.require_member(h);
 IF i IS NULL OR t IS NULL OR length(btrim(t)) NOT BETWEEN 1 AND 160 OR b IS NULL OR e IS NULL OR e<=b OR e-b>interval '367 days' OR full_day IS NULL OR scope IS NULL OR scope NOT IN('private','parents','family') OR n IS NULL OR length(n)>2000 THEN RAISE EXCEPTION 'Invalid calendar event' USING ERRCODE='22023';END IF;
 IF r='child' AND scope<>'family' THEN RAISE EXCEPTION 'Children create family-visible events' USING ERRCODE='42501';END IF;
 -- Per-event advisory lock also serializes first insert/retries.
 PERFORM pg_advisory_xact_lock(hashtextextended(i::text,0));
 SELECT * INTO old FROM public.bb_calendar_events WHERE id=i FOR UPDATE;
 IF FOUND THEN
  IF old.household_id<>h OR (old.created_by<>actor AND (r<>'adult' OR old.visibility='private')) THEN RAISE EXCEPTION 'Event edit denied' USING ERRCODE='42501';END IF;
  IF v IS NULL AND old.created_by=actor AND old.status='active' AND old.title=btrim(t) AND old.starts_at=b AND old.ends_at=e AND old.all_day=full_day AND old.visibility=scope AND old.notes=n THEN RETURN to_jsonb(old);END IF;
  IF v IS NULL OR v<>old.version THEN RAISE EXCEPTION 'Event changed elsewhere' USING ERRCODE='40001';END IF;
  IF old.status<>'active' THEN RAISE EXCEPTION 'Cancelled event cannot be edited' USING ERRCODE='55000';END IF;
  -- Parents may manage visible shared events but cannot privatize someone else's event.
  IF old.created_by<>actor AND scope<>old.visibility THEN RAISE EXCEPTION 'Only creator can change event visibility' USING ERRCODE='42501';END IF;
  UPDATE public.bb_calendar_events SET title=btrim(t),starts_at=b,ends_at=e,all_day=full_day,visibility=scope,notes=n,version=version+1,updated_at=clock_timestamp() WHERE id=i RETURNING * INTO next;
 ELSE
  IF v IS NOT NULL THEN RAISE EXCEPTION 'Event unavailable' USING ERRCODE='42501';END IF;
  INSERT INTO public.bb_calendar_events(id,household_id,created_by,title,starts_at,ends_at,all_day,visibility,notes) VALUES(i,h,actor,btrim(t),b,e,full_day,scope,n) RETURNING * INTO next;
 END IF;
 INSERT INTO bb_planner_private.calendar_changes(event_id,household_id,actor_id,action,before_state,after_state) VALUES(i,h,actor,CASE WHEN old.id IS NULL THEN 'created' ELSE 'edited' END,CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(next));
 RETURN to_jsonb(next);
END $$;
CREATE FUNCTION bb_planner_private.calendar_cancel(i uuid,v bigint) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE old public.bb_calendar_events; next public.bb_calendar_events; r text;actor uuid:=bb_planner_private.actor_uid();
BEGIN
 SELECT * INTO old FROM public.bb_calendar_events WHERE id=i FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Event unavailable' USING ERRCODE='42501';END IF;
 r:=bb_planner_private.require_member(old.household_id);
 IF old.created_by<>actor AND (r<>'adult' OR old.visibility='private') THEN RAISE EXCEPTION 'Cancellation denied' USING ERRCODE='42501';END IF;
 IF v IS NULL OR v<>old.version THEN RAISE EXCEPTION 'Event changed elsewhere' USING ERRCODE='40001';END IF;
 IF old.status='cancelled' THEN RETURN to_jsonb(old);END IF;
 UPDATE public.bb_calendar_events SET status='cancelled',version=version+1,updated_at=clock_timestamp() WHERE id=i RETURNING * INTO next;
 INSERT INTO bb_planner_private.calendar_changes(event_id,household_id,actor_id,action,before_state,after_state) VALUES(i,old.household_id,actor,'cancelled',to_jsonb(old),to_jsonb(next));
 RETURN to_jsonb(next);
END $$;
GRANT CREATE ON SCHEMA bb_planner_private TO bb_calendar_writer;
ALTER FUNCTION bb_planner_private.calendar_save(uuid,uuid,bigint,text,timestamptz,timestamptz,boolean,text,text) OWNER TO bb_calendar_writer;
ALTER FUNCTION bb_planner_private.calendar_cancel(uuid,bigint) OWNER TO bb_calendar_writer;
REVOKE CREATE ON SCHEMA bb_planner_private FROM bb_calendar_writer;
REVOKE ALL ON FUNCTION bb_planner_private.calendar_save(uuid,uuid,bigint,text,timestamptz,timestamptz,boolean,text,text),bb_planner_private.calendar_cancel(uuid,bigint) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION bb_planner_private.calendar_save(uuid,uuid,bigint,text,timestamptz,timestamptz,boolean,text,text),bb_planner_private.calendar_cancel(uuid,bigint) TO authenticated;
CREATE FUNCTION public.bb_calendar_save(h uuid,i uuid,v bigint,t text,b timestamptz,e timestamptz,full_day boolean,scope text,n text) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.calendar_save(h,i,v,t,b,e,full_day,scope,n) $$;
CREATE FUNCTION public.bb_calendar_cancel(i uuid,v bigint) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.calendar_cancel(i,v) $$;
REVOKE ALL ON FUNCTION public.bb_calendar_save(uuid,uuid,bigint,text,timestamptz,timestamptz,boolean,text,text),public.bb_calendar_cancel(uuid,bigint) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.bb_calendar_save(uuid,uuid,bigint,text,timestamptz,timestamptz,boolean,text,text),public.bb_calendar_cancel(uuid,bigint) TO authenticated;
NOTIFY pgrst,'reload schema';
