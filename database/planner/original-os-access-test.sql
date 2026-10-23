BEGIN;
DO $test$
DECLARE w public.bb_os_workspaces; other_adult uuid; child_id uuid; outsider uuid; n integer; result jsonb; changed jsonb;
BEGIN
 SELECT * INTO STRICT w FROM public.bb_os_workspaces ORDER BY updated_at DESC LIMIT 1;
 SELECT user_id INTO other_adult FROM public.bb_planner_members WHERE household_id=w.household_id AND member_role='adult' AND user_id<>w.owner_id LIMIT 1;
 SELECT user_id INTO child_id FROM public.bb_planner_members WHERE household_id=w.household_id AND member_role='child' LIMIT 1;
 SELECT user_id INTO outsider FROM public.bb_planner_members m WHERE NOT EXISTS(SELECT FROM public.bb_planner_members x WHERE x.household_id=w.household_id AND x.user_id=m.user_id) LIMIT 1;
 PERFORM set_config('request.jwt.claim.sub',w.owner_id::text,true);EXECUTE 'SET LOCAL ROLE authenticated';
 SELECT count(*) INTO n FROM public.bb_os_sources WHERE id=w.source_id;IF n<>1 THEN RAISE EXCEPTION 'Owner source read failed';END IF;
 changed:=jsonb_set(w.storage,'{steven-os-rollback-test-marker}',to_jsonb(gen_random_uuid()::text));
 result:=public.bb_os_save(w.id,w.version,changed);IF (result->>'version')::bigint<>w.version+1 THEN RAISE EXCEPTION 'Save failed';END IF;
 BEGIN PERFORM public.bb_os_save(w.id,w.version,w.storage);RAISE EXCEPTION 'Stale overwrite accepted';EXCEPTION WHEN serialization_failure THEN NULL;END;
 SELECT count(*) INTO n FROM public.bb_os_revisions WHERE workspace_id=w.id AND version=w.version AND storage=w.storage;IF n<>1 THEN RAISE EXCEPTION 'Prior version not preserved';END IF;
 BEGIN PERFORM public.bb_os_save(w.id,w.version+1,jsonb_build_object('steven-os-v60-data','{}'));RAISE EXCEPTION 'Invalid events snapshot accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 BEGIN UPDATE public.bb_os_sources SET html='' WHERE id=w.source_id;RAISE EXCEPTION 'Direct source write allowed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 PERFORM set_config('request.jwt.claim.sub',other_adult::text,true);SELECT count(*) INTO n FROM public.bb_os_sources WHERE id=w.source_id;IF n<>0 THEN RAISE EXCEPTION 'Other adult source leak';END IF;
 BEGIN PERFORM public.bb_os_save(w.id,w.version+1,changed);RAISE EXCEPTION 'Other adult write accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 PERFORM set_config('request.jwt.claim.sub',child_id::text,true);SELECT count(*) INTO n FROM public.bb_os_workspaces WHERE id=w.id;IF n<>0 THEN RAISE EXCEPTION 'Child workspace leak';END IF;
 PERFORM set_config('request.jwt.claim.sub',outsider::text,true);SELECT count(*) INTO n FROM public.bb_os_sources WHERE id=w.source_id;IF n<>0 THEN RAISE EXCEPTION 'Outsider source leak';END IF;
 EXECUTE 'SET LOCAL ROLE postgres';
 IF has_table_privilege('anon','public.bb_os_sources','SELECT') OR has_function_privilege('anon','public.bb_os_save(uuid,bigint,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous exposure';END IF;
 RAISE NOTICE 'PASS owner source/save, preserved prior version, stale conflict, other-parent/child/outsider/anon denial, immutable source';
END $test$;
ROLLBACK;
