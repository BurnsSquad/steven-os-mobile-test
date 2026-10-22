-- Additive household groceries; original private grocery/spending records are untouched.
CREATE TABLE public.bb_grocery_items(
 id uuid PRIMARY KEY,household_id uuid NOT NULL,created_by uuid NOT NULL,
 title text NOT NULL CHECK(length(btrim(title)) BETWEEN 1 AND 160),quantity text NOT NULL DEFAULT '' CHECK(length(quantity)<=120),
 is_picked boolean NOT NULL DEFAULT false,picked_by uuid,picked_at timestamptz,is_archived boolean NOT NULL DEFAULT false,
 version bigint NOT NULL DEFAULT 1 CHECK(version>0),created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(household_id,created_by) REFERENCES public.bb_planner_members(household_id,user_id),
 FOREIGN KEY(household_id,picked_by) REFERENCES public.bb_planner_members(household_id,user_id),
 CHECK((is_picked AND picked_by IS NOT NULL AND picked_at IS NOT NULL) OR (NOT is_picked AND picked_by IS NULL AND picked_at IS NULL)));
CREATE INDEX grocery_household_list ON public.bb_grocery_items(household_id,is_archived,created_at,id);
CREATE INDEX grocery_creator ON public.bb_grocery_items(household_id,created_by);
CREATE INDEX grocery_picker ON public.bb_grocery_items(household_id,picked_by);
CREATE TABLE bb_planner_private.grocery_changes(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),item_id uuid NOT NULL REFERENCES public.bb_grocery_items(id),household_id uuid NOT NULL,actor_id uuid NOT NULL,action text NOT NULL CHECK(action IN('add','edit','pick','archive')),before_state jsonb,after_state jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX grocery_change_item ON bb_planner_private.grocery_changes(item_id,created_at);
ALTER TABLE public.bb_grocery_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE bb_planner_private.grocery_changes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bb_grocery_items,bb_planner_private.grocery_changes FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.bb_grocery_items TO authenticated;
CREATE POLICY grocery_member_read ON public.bb_grocery_items FOR SELECT TO authenticated USING(EXISTS(SELECT FROM public.bb_planner_members m WHERE m.household_id=bb_grocery_items.household_id AND m.user_id=(SELECT auth.uid())));
CREATE ROLE bb_grocery_writer NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT bb_grocery_writer TO postgres;
GRANT USAGE ON SCHEMA public,bb_planner_private TO bb_grocery_writer;
GRANT SELECT ON public.bb_planner_members,public.bb_grocery_items TO bb_grocery_writer;
GRANT INSERT ON public.bb_grocery_items,bb_planner_private.grocery_changes TO bb_grocery_writer;
GRANT UPDATE(title,quantity,is_picked,picked_by,picked_at,is_archived,version,updated_at) ON public.bb_grocery_items TO bb_grocery_writer;
CREATE POLICY grocery_writer_member ON public.bb_planner_members FOR SELECT TO bb_grocery_writer USING(true);
CREATE POLICY grocery_writer_read ON public.bb_grocery_items FOR SELECT TO bb_grocery_writer USING(true);
CREATE POLICY grocery_writer_add ON public.bb_grocery_items FOR INSERT TO bb_grocery_writer WITH CHECK(true);
CREATE POLICY grocery_writer_edit ON public.bb_grocery_items FOR UPDATE TO bb_grocery_writer USING(true) WITH CHECK(true);
CREATE POLICY grocery_writer_audit ON bb_planner_private.grocery_changes FOR INSERT TO bb_grocery_writer WITH CHECK(true);
GRANT EXECUTE ON FUNCTION bb_planner_private.actor_uid(),bb_planner_private.require_member(uuid) TO bb_grocery_writer;
CREATE FUNCTION bb_planner_private.grocery_write(h uuid,i uuid,v bigint,op text,t text,q text,picked boolean) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE role_name text;actor uuid:=bb_planner_private.actor_uid();old public.bb_grocery_items;next public.bb_grocery_items;
BEGIN
 role_name:=bb_planner_private.require_member(h);
 IF i IS NULL OR op IS NULL OR op NOT IN('add','edit','pick','archive') THEN RAISE EXCEPTION 'Invalid grocery command' USING ERRCODE='22023';END IF;
 IF op IN('add','edit') AND (t IS NULL OR length(btrim(t)) NOT BETWEEN 1 AND 160 OR q IS NULL OR length(q)>120) OR op='pick' AND picked IS NULL THEN RAISE EXCEPTION 'Invalid grocery fields' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(i::text,0));
 SELECT * INTO old FROM public.bb_grocery_items WHERE id=i FOR UPDATE;
 IF op='add' THEN
  IF v IS NOT NULL THEN RAISE EXCEPTION 'New item version invalid' USING ERRCODE='22023';END IF;
  IF FOUND THEN
   IF old.household_id<>h OR old.created_by<>actor THEN RAISE EXCEPTION 'Item unavailable' USING ERRCODE='42501';END IF;
   IF old.title=btrim(t) AND old.quantity=btrim(q) AND NOT old.is_archived THEN RETURN to_jsonb(old);END IF;
   RAISE EXCEPTION 'Item changed elsewhere' USING ERRCODE='40001';
  END IF;
  INSERT INTO public.bb_grocery_items(id,household_id,created_by,title,quantity) VALUES(i,h,actor,btrim(t),btrim(q)) RETURNING * INTO next;
 ELSE
  IF old.id IS NULL OR old.household_id<>h THEN RAISE EXCEPTION 'Item unavailable' USING ERRCODE='42501';END IF;
  IF op='archive' AND role_name<>'adult' OR op='edit' AND role_name<>'adult' AND old.created_by<>actor THEN RAISE EXCEPTION 'Item change denied' USING ERRCODE='42501';END IF;
  IF v IS NULL OR v<>old.version THEN RAISE EXCEPTION 'Item changed elsewhere' USING ERRCODE='40001';END IF;
  IF old.is_archived THEN RAISE EXCEPTION 'Archived item is read-only' USING ERRCODE='55000';END IF;
  UPDATE public.bb_grocery_items SET title=CASE WHEN op='edit' THEN btrim(t) ELSE title END,quantity=CASE WHEN op='edit' THEN btrim(q) ELSE quantity END,
   is_picked=CASE WHEN op='pick' THEN picked ELSE is_picked END,picked_by=CASE WHEN op='pick' THEN CASE WHEN picked THEN actor ELSE NULL END ELSE picked_by END,
   picked_at=CASE WHEN op='pick' THEN CASE WHEN picked THEN clock_timestamp() ELSE NULL END ELSE picked_at END,
   is_archived=op='archive',version=version+1,updated_at=clock_timestamp() WHERE id=i RETURNING * INTO next;
 END IF;
 INSERT INTO bb_planner_private.grocery_changes(item_id,household_id,actor_id,action,before_state,after_state) VALUES(i,h,actor,op,CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(next));
 RETURN to_jsonb(next);
END $$;
GRANT CREATE ON SCHEMA bb_planner_private TO bb_grocery_writer;
ALTER FUNCTION bb_planner_private.grocery_write(uuid,uuid,bigint,text,text,text,boolean) OWNER TO bb_grocery_writer;
REVOKE CREATE ON SCHEMA bb_planner_private FROM bb_grocery_writer;
REVOKE ALL ON FUNCTION bb_planner_private.grocery_write(uuid,uuid,bigint,text,text,text,boolean) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION bb_planner_private.grocery_write(uuid,uuid,bigint,text,text,text,boolean) TO authenticated;
CREATE FUNCTION public.bb_grocery_write(h uuid,i uuid,v bigint,op text,t text,q text,picked boolean) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.grocery_write(h,i,v,op,t,q,picked) $$;
REVOKE ALL ON FUNCTION public.bb_grocery_write(uuid,uuid,bigint,text,text,text,boolean) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.bb_grocery_write(uuid,uuid,bigint,text,text,text,boolean) TO authenticated;
