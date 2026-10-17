-- REVIEWED APPLICATION REQUIRED. Additive planner v1; never touches bb_test_*.
-- Caller must independently verify isolated project, then set the session opt-in.
BEGIN;
DO $guard$ BEGIN
 IF current_user <> 'postgres' OR current_setting('bb_planner.approved_schema',true) IS DISTINCT FROM 'planner-v1' THEN
  RAISE EXCEPTION 'Verified administrator and explicit planner-v1 opt-in required';
 END IF;
 IF EXISTS(SELECT FROM pg_roles WHERE rolname='bb_planner_executor') THEN
  RAISE EXCEPTION 'Planner role already exists; do not overwrite';
 END IF;
END $guard$;
CREATE ROLE bb_planner_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT bb_planner_executor TO postgres;
CREATE SCHEMA bb_planner_private;
REVOKE ALL ON SCHEMA bb_planner_private FROM PUBLIC,anon,authenticated,service_role;
GRANT USAGE ON SCHEMA bb_planner_private TO authenticated,bb_planner_executor;
GRANT USAGE ON SCHEMA public TO bb_planner_executor;

CREATE TABLE public.bb_planner_households (
 id uuid PRIMARY KEY, label text NOT NULL CHECK(length(btrim(label)) BETWEEN 1 AND 120),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.bb_planner_members (
 household_id uuid NOT NULL REFERENCES public.bb_planner_households(id),
 user_id uuid NOT NULL REFERENCES auth.users(id),
 member_role text NOT NULL CHECK(member_role IN ('adult','child')),
 created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(household_id,user_id)
);
CREATE INDEX bb_planner_members_user ON public.bb_planner_members(user_id,household_id);
CREATE TABLE public.bb_planner_items (
 id uuid PRIMARY KEY, household_id uuid NOT NULL REFERENCES public.bb_planner_households(id),
 created_by uuid NOT NULL, item_type text NOT NULL CHECK(item_type IN ('task','activity')),
 title text NOT NULL CHECK(length(btrim(title)) BETWEEN 1 AND 120),
 completion_mode text NOT NULL CHECK(completion_mode IN ('individual','household','shared')),
 version bigint NOT NULL DEFAULT 1 CHECK(version>0),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(household_id,created_by) REFERENCES public.bb_planner_members(household_id,user_id),
 UNIQUE(id,household_id)
);
CREATE INDEX bb_planner_items_household ON public.bb_planner_items(household_id,created_at,id);
CREATE TABLE public.bb_planner_assignments (
 item_id uuid NOT NULL, household_id uuid NOT NULL, assignee_id uuid NOT NULL,
 PRIMARY KEY(item_id,assignee_id),
 FOREIGN KEY(item_id,household_id) REFERENCES public.bb_planner_items(id,household_id),
 FOREIGN KEY(household_id,assignee_id) REFERENCES public.bb_planner_members(household_id,user_id)
);
CREATE INDEX bb_planner_assignments_household ON public.bb_planner_assignments(household_id,item_id);
CREATE TABLE public.bb_planner_completions (
 item_id uuid NOT NULL, household_id uuid NOT NULL, contribution_key text NOT NULL,
 assignee_id uuid NOT NULL, actor_id uuid NOT NULL, completed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(item_id,contribution_key), UNIQUE(item_id,assignee_id),
 FOREIGN KEY(item_id,assignee_id) REFERENCES public.bb_planner_assignments(item_id,assignee_id),
 FOREIGN KEY(item_id,household_id) REFERENCES public.bb_planner_items(id,household_id),
 FOREIGN KEY(household_id,actor_id) REFERENCES public.bb_planner_members(household_id,user_id)
);
CREATE INDEX bb_planner_completions_household ON public.bb_planner_completions(household_id,item_id);
CREATE TABLE public.bb_planner_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), item_id uuid NOT NULL, household_id uuid NOT NULL,
 actor_id uuid NOT NULL, action text NOT NULL CHECK(action IN ('created','renamed','assigned','completed')),
 details jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(item_id,household_id) REFERENCES public.bb_planner_items(id,household_id),
 FOREIGN KEY(household_id,actor_id) REFERENCES public.bb_planner_members(household_id,user_id)
);
CREATE INDEX bb_planner_events_household ON public.bb_planner_events(household_id,item_id,created_at);

-- Trusted capability boundary: no API-role INSERT/UPDATE/DELETE and no public definer.
-- Executor has privileges only on these NEW objects and still obeys RLS.
REVOKE ALL ON ALL TABLES IN SCHEMA bb_planner_private FROM PUBLIC,anon,authenticated;
REVOKE ALL ON public.bb_planner_households,public.bb_planner_members,public.bb_planner_items,
 public.bb_planner_assignments,public.bb_planner_completions,public.bb_planner_events
 FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.bb_planner_households,public.bb_planner_members,public.bb_planner_items,
 public.bb_planner_assignments,public.bb_planner_completions,public.bb_planner_events TO authenticated,bb_planner_executor;
GRANT INSERT ON public.bb_planner_items,public.bb_planner_assignments,public.bb_planner_completions,public.bb_planner_events TO bb_planner_executor;
GRANT UPDATE(title,completion_mode,version,updated_at) ON public.bb_planner_items TO bb_planner_executor;
GRANT DELETE ON public.bb_planner_assignments TO bb_planner_executor;

ALTER TABLE public.bb_planner_households ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_planner_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_planner_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_planner_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_planner_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_planner_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY planner_own_membership ON public.bb_planner_members FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
CREATE POLICY planner_household_read ON public.bb_planner_households FOR SELECT TO authenticated
 USING(id IN (SELECT household_id FROM public.bb_planner_members WHERE user_id=(SELECT auth.uid())));
CREATE POLICY planner_item_read ON public.bb_planner_items FOR SELECT TO authenticated
 USING(household_id IN (SELECT household_id FROM public.bb_planner_members WHERE user_id=(SELECT auth.uid())));
CREATE POLICY planner_assignment_read ON public.bb_planner_assignments FOR SELECT TO authenticated
 USING(household_id IN (SELECT household_id FROM public.bb_planner_members WHERE user_id=(SELECT auth.uid())));
CREATE POLICY planner_completion_read ON public.bb_planner_completions FOR SELECT TO authenticated
 USING(household_id IN (SELECT household_id FROM public.bb_planner_members WHERE user_id=(SELECT auth.uid())));
CREATE POLICY planner_event_read ON public.bb_planner_events FOR SELECT TO authenticated
 USING(household_id IN (SELECT household_id FROM public.bb_planner_members WHERE user_id=(SELECT auth.uid())));
-- Policies specific to the NOLOGIN executor, never granted to browser roles.
CREATE POLICY planner_executor_households ON public.bb_planner_households FOR SELECT TO bb_planner_executor USING(true);
CREATE POLICY planner_executor_members ON public.bb_planner_members FOR SELECT TO bb_planner_executor USING(true);
CREATE POLICY planner_executor_items_read ON public.bb_planner_items FOR SELECT TO bb_planner_executor USING(true);
CREATE POLICY planner_executor_items_insert ON public.bb_planner_items FOR INSERT TO bb_planner_executor WITH CHECK(true);
CREATE POLICY planner_executor_items_update ON public.bb_planner_items FOR UPDATE TO bb_planner_executor USING(true) WITH CHECK(true);
CREATE POLICY planner_executor_assignments ON public.bb_planner_assignments FOR ALL TO bb_planner_executor USING(true) WITH CHECK(true);
CREATE POLICY planner_executor_completions_read ON public.bb_planner_completions FOR SELECT TO bb_planner_executor USING(true);
CREATE POLICY planner_executor_completions_insert ON public.bb_planner_completions FOR INSERT TO bb_planner_executor WITH CHECK(true);
CREATE POLICY planner_executor_events_read ON public.bb_planner_events FOR SELECT TO bb_planner_executor USING(true);
CREATE POLICY planner_executor_events_insert ON public.bb_planner_events FOR INSERT TO bb_planner_executor WITH CHECK(true);

-- Mirrors the verified hosted auth.uid() implementation without requiring access
-- to Supabase's managed auth schema. Claims are supplied by verified PostgREST;
-- clients cannot pass an actor/role parameter or use editable profile metadata.
CREATE FUNCTION bb_planner_private.actor_uid() RETURNS uuid
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
 SELECT coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),
 (nullif(current_setting('request.jwt.claims',true),'')::jsonb ->> 'sub'))::uuid
$$;
CREATE FUNCTION bb_planner_private.require_member(h uuid) RETURNS text
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE r text; BEGIN
 IF bb_planner_private.actor_uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 SELECT member_role INTO r FROM public.bb_planner_members WHERE household_id=h AND user_id=bb_planner_private.actor_uid();
 IF r IS NULL THEN RAISE EXCEPTION 'Household access denied' USING ERRCODE='42501'; END IF;
 RETURN r;
END $$;
CREATE FUNCTION bb_planner_private.check_assignments(h uuid,m text,ids uuid[]) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
BEGIN
 IF m IS NULL OR m NOT IN ('individual','household','shared') OR ids IS NULL OR cardinality(ids)<1 OR cardinality(ids)>100
 OR array_position(ids,NULL) IS NOT NULL OR (m='individual' AND cardinality(ids)<>1)
 OR (SELECT count(DISTINCT x) FROM unnest(ids) x)<>cardinality(ids)
 OR (SELECT count(*) FROM public.bb_planner_members WHERE household_id=h AND user_id=ANY(ids))<>cardinality(ids)
 THEN RAISE EXCEPTION 'Invalid assignment set' USING ERRCODE='22023'; END IF;
END $$;
CREATE FUNCTION bb_planner_private.item_state(i uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
 SELECT to_jsonb(t) || jsonb_build_object(
  'assignees',(SELECT jsonb_agg(a.assignee_id ORDER BY a.assignee_id) FROM public.bb_planner_assignments a WHERE a.item_id=t.id),
  'completions',COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.contribution_key) FROM public.bb_planner_completions c WHERE c.item_id=t.id),'[]'::jsonb),
  'complete',CASE WHEN t.completion_mode='shared' THEN
    (SELECT count(*) FROM public.bb_planner_assignments a WHERE a.item_id=t.id)=(SELECT count(*) FROM public.bb_planner_completions c WHERE c.item_id=t.id)
    ELSE EXISTS(SELECT FROM public.bb_planner_completions c WHERE c.item_id=t.id) END)
 FROM public.bb_planner_items t WHERE t.id=i
$$;

CREATE FUNCTION bb_planner_private.create_item(h uuid,i uuid,k text,t text,m text,ids uuid[]) RETURNS jsonb
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
CREATE FUNCTION bb_planner_private.rename_item(i uuid,t text,v bigint) RETURNS jsonb
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
CREATE FUNCTION bb_planner_private.assign_item(i uuid,m text,ids uuid[],v bigint) RETURNS jsonb
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
CREATE FUNCTION bb_planner_private.complete_item(i uuid,for_member uuid) RETURNS jsonb
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
CREATE FUNCTION bb_planner_private.list_items(h uuid) RETURNS SETOF jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM bb_planner_private.require_member(h);
 RETURN QUERY SELECT bb_planner_private.item_state(id) FROM public.bb_planner_items WHERE household_id=h ORDER BY created_at,id;
END $$;

-- Only unprivileged invoker wrappers are exposed through the public API.
CREATE FUNCTION public.bb_planner_create(h uuid,i uuid,k text,t text,m text,ids uuid[]) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.create_item(h,i,k,t,m,ids) $$;
CREATE FUNCTION public.bb_planner_rename(i uuid,t text,v bigint) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.rename_item(i,t,v) $$;
CREATE FUNCTION public.bb_planner_assign(i uuid,m text,ids uuid[],v bigint) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.assign_item(i,m,ids,v) $$;
CREATE FUNCTION public.bb_planner_complete(i uuid,for_member uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.complete_item(i,for_member) $$;
CREATE FUNCTION public.bb_planner_list(h uuid) RETURNS SETOF jsonb
LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT * FROM bb_planner_private.list_items(h) $$;

-- Fixed object lists prevent this proposal from changing any existing function ACL.
GRANT CREATE ON SCHEMA bb_planner_private TO bb_planner_executor;
ALTER FUNCTION bb_planner_private.actor_uid() OWNER TO bb_planner_executor;
ALTER FUNCTION bb_planner_private.require_member(uuid) OWNER TO bb_planner_executor;
ALTER FUNCTION bb_planner_private.check_assignments(uuid,text,uuid[]) OWNER TO bb_planner_executor;
ALTER FUNCTION bb_planner_private.item_state(uuid) OWNER TO bb_planner_executor;
ALTER FUNCTION bb_planner_private.create_item(uuid,uuid,text,text,text,uuid[]) OWNER TO bb_planner_executor;
ALTER FUNCTION bb_planner_private.rename_item(uuid,text,bigint) OWNER TO bb_planner_executor;
ALTER FUNCTION bb_planner_private.assign_item(uuid,text,uuid[],bigint) OWNER TO bb_planner_executor;
ALTER FUNCTION bb_planner_private.complete_item(uuid,uuid) OWNER TO bb_planner_executor;
ALTER FUNCTION bb_planner_private.list_items(uuid) OWNER TO bb_planner_executor;
REVOKE CREATE ON SCHEMA bb_planner_private FROM bb_planner_executor;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA bb_planner_private FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION bb_planner_private.create_item(uuid,uuid,text,text,text,uuid[]),
 bb_planner_private.rename_item(uuid,text,bigint),bb_planner_private.assign_item(uuid,text,uuid[],bigint),
 bb_planner_private.complete_item(uuid,uuid),bb_planner_private.list_items(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.bb_planner_create(uuid,uuid,text,text,text,uuid[]),public.bb_planner_rename(uuid,text,bigint),
 public.bb_planner_assign(uuid,text,uuid[],bigint),public.bb_planner_complete(uuid,uuid),public.bb_planner_list(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.bb_planner_create(uuid,uuid,text,text,text,uuid[]),public.bb_planner_rename(uuid,text,bigint),
 public.bb_planner_assign(uuid,text,uuid[],bigint),public.bb_planner_complete(uuid,uuid),public.bb_planner_list(uuid) TO authenticated;
COMMIT;
