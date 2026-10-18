-- Administrator-driven role simulation, all data edits rolled back.
BEGIN;
DO $test$
DECLARE r record; a uuid; child_id uuid; outsider uuid; result jsonb; taskid uuid; oldversion bigint; n integer;
BEGIN
 SELECT * INTO r FROM bb_planner_private.routines LIMIT 1;
 SELECT user_id INTO a FROM public.bb_planner_members WHERE household_id=r.household_id AND member_role='adult' ORDER BY user_id LIMIT 1;
 SELECT user_id INTO child_id FROM public.bb_planner_members WHERE household_id=r.household_id AND member_role='child' ORDER BY user_id LIMIT 1;
 SELECT user_id INTO outsider FROM public.bb_planner_members m WHERE NOT EXISTS(SELECT FROM public.bb_planner_members x WHERE x.household_id=r.household_id AND x.user_id=m.user_id) LIMIT 1;
 IF a IS NULL OR child_id IS NULL OR outsider IS NULL THEN RAISE EXCEPTION 'Fixture requirements'; END IF;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 EXECUTE 'SET LOCAL ROLE authenticated';
 SELECT x INTO result FROM public.bb_planner_routines(r.household_id) x;
 IF result->>'id'<>r.id::text THEN RAISE EXCEPTION 'Adult list'; END IF;
 result:=public.bb_planner_routine_save(r.id,r.version,'18:37',ARRAY[1,3,5],true);
 IF result->>'time'<>'18:37' OR result->'weekdays'<>'[1,3,5]'::jsonb THEN RAISE EXCEPTION 'Schedule save'; END IF;
 BEGIN PERFORM public.bb_planner_routine_save(r.id,r.version,'19:00',ARRAY[1],true); RAISE EXCEPTION 'Stale save accepted'; EXCEPTION WHEN serialization_failure THEN NULL; END;
 oldversion:=(result->>'version')::bigint;
 BEGIN PERFORM public.bb_planner_routine_save(r.id,oldversion,'24:01',ARRAY[1],true); RAISE EXCEPTION 'Bad time accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.bb_planner_routine_save(r.id,oldversion,'19:00',ARRAY[1,1],true); RAISE EXCEPTION 'Duplicate days accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.bb_planner_routine_task_save(r.id,oldversion,NULL,'Test only','individual',ARRAY[outsider],true); RAISE EXCEPTION 'Foreign assignee accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 result:=public.bb_planner_routine_task_save(r.id,oldversion,NULL,'Rollback-only repeating Task','individual',ARRAY[child_id],true);
 SELECT (t->>'id')::uuid INTO taskid FROM jsonb_array_elements(result->'templates') t WHERE t->>'title'='Rollback-only repeating Task';
 result:=public.bb_planner_routine_task_save(r.id,(result->>'version')::bigint,taskid,'Rollback-only revised Task','shared',ARRAY[a,child_id],false);
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(result->'templates') t WHERE t->>'id'=taskid::text AND t->>'enabled'='false' AND t->>'mode'='shared') THEN RAISE EXCEPTION 'Template edit'; END IF;
 PERFORM set_config('request.jwt.claim.sub',child_id::text,true);
 BEGIN PERFORM public.bb_planner_routines(r.household_id); RAISE EXCEPTION 'Child list accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.bb_planner_routine_save(r.id,(result->>'version')::bigint,'19:00',ARRAY[1],false); RAISE EXCEPTION 'Child mutation accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub',outsider::text,true);
 BEGIN PERFORM public.bb_planner_routines(r.household_id); RAISE EXCEPTION 'Outsider list accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 EXECUTE 'SET LOCAL ROLE postgres';
 IF has_function_privilege('anon','public.bb_planner_routines(uuid)','EXECUTE') OR has_table_privilege('authenticated','bb_planner_private.routines','UPDATE') THEN RAISE EXCEPTION 'ACL exposure'; END IF;
 -- Generator respects chosen weekdays, minute precision and paused templates.
 UPDATE bb_planner_private.routines SET enabled=false;
 UPDATE bb_planner_private.routines SET enabled=true WHERE id=r.id;
 n:=bb_planner_private.generate_evening_routines('2027-03-15 22:36:00+00'); IF n<>0 THEN RAISE EXCEPTION 'Early'; END IF;
 n:=bb_planner_private.generate_evening_routines('2027-03-15 22:37:00+00'); IF n<>3 THEN RAISE EXCEPTION 'Paused template or minute boundary %',n; END IF;
 n:=bb_planner_private.generate_evening_routines('2027-03-16 23:00:00+00'); IF n<>0 THEN RAISE EXCEPTION 'Unselected day'; END IF;
 RAISE NOTICE 'PASS adult editing, invalid inputs, stale conflict, foreign assignee, child/outsider denial, private ACLs, minute/day/paused generation';
END $test$;
ROLLBACK;
