CREATE OR REPLACE FUNCTION bb_planner_private.os_save(i uuid,v bigint,s jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE w public.bb_os_workspaces; body jsonb;
BEGIN
 SELECT * INTO w FROM public.bb_os_workspaces WHERE id=i FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Workspace unavailable' USING ERRCODE='42501';END IF;
 IF w.owner_id IS DISTINCT FROM bb_planner_private.actor_uid() OR bb_planner_private.require_member(w.household_id)<>'adult' THEN RAISE EXCEPTION 'Private workspace denied' USING ERRCODE='42501';END IF;
 IF v IS NULL OR v<>w.version THEN RAISE EXCEPTION 'Workspace changed elsewhere' USING ERRCODE='40001';END IF;
 IF s IS NULL OR jsonb_typeof(s)<>'object' OR octet_length(s::text)>5000000 OR NOT(s?'steven-os-v60-data') OR EXISTS(SELECT FROM jsonb_each(s) x WHERE jsonb_typeof(x.value)<>'string' OR x.key !~ '^steven-os-[a-zA-Z0-9_-]{1,100}$') THEN RAISE EXCEPTION 'Invalid workspace snapshot' USING ERRCODE='22023';END IF;
 BEGIN body:=(s->>'steven-os-v60-data')::jsonb;EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'Invalid workspace JSON' USING ERRCODE='22023';END;
 IF jsonb_typeof(body) IS DISTINCT FROM 'object' OR jsonb_typeof(body->'events') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Invalid workspace events' USING ERRCODE='22023';END IF;
 IF s=w.storage THEN RETURN jsonb_build_object('id',i,'version',v);END IF;
 INSERT INTO public.bb_os_revisions(workspace_id,version,storage,actor_id) VALUES(i,w.version,w.storage,w.owner_id);
 UPDATE public.bb_os_workspaces SET storage=s,version=version+1,updated_at=clock_timestamp() WHERE id=i;
 RETURN jsonb_build_object('id',i,'version',v+1);
END $$;

CREATE INDEX os_sources_membership_fk ON public.bb_os_sources(household_id,owner_id);
CREATE INDEX os_workspaces_membership_fk ON public.bb_os_workspaces(household_id,owner_id);
