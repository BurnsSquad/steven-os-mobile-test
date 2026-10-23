-- Administrator SQL tests, rollback only; not a real browser/JWT test.
BEGIN;
DO $test$
DECLARE n integer; before_items bigint; first_item uuid; owner uuid;
BEGIN
 SELECT count(*) INTO before_items FROM public.bb_planner_items;
 IF has_function_privilege('anon','bb_planner_private.generate_evening_routines(timestamptz)','EXECUTE') OR has_function_privilege('authenticated','bb_planner_private.generate_evening_routines(timestamptz)','EXECUTE') OR has_function_privilege('service_role','bb_planner_private.generate_evening_routines(timestamptz)','EXECUTE') THEN RAISE EXCEPTION 'Scheduler exposed'; END IF;
 IF has_table_privilege('authenticated','bb_planner_private.routines','SELECT') OR has_table_privilege('authenticated','bb_planner_private.routine_templates','INSERT') THEN RAISE EXCEPTION 'Templates exposed'; END IF;
 n:=bb_planner_private.generate_evening_routines('2027-03-13 21:59:00+00'); IF n<>0 THEN RAISE EXCEPTION 'Winter early generation'; END IF;
 n:=bb_planner_private.generate_evening_routines('2027-03-13 22:00:00+00'); IF n<>3 THEN RAISE EXCEPTION 'Winter evening count %',n; END IF;
 n:=bb_planner_private.generate_evening_routines('2027-03-13 23:00:00+00'); IF n<>0 THEN RAISE EXCEPTION 'Duplicate generation'; END IF;
 SELECT o.item_id,r.owner_id INTO first_item,owner FROM bb_planner_private.routine_occurrences o JOIN bb_planner_private.routine_templates t ON t.id=o.template_id JOIN bb_planner_private.routines r ON r.id=t.routine_id WHERE o.evening_date='2027-03-13' AND t.completion_mode='household';
 PERFORM set_config('request.jwt.claim.sub',owner::text,true);
 PERFORM public.bb_planner_complete(first_item);
 n:=bb_planner_private.generate_evening_routines('2027-03-14 20:59:00+00'); IF n<>0 THEN RAISE EXCEPTION 'Summer early generation'; END IF;
 n:=bb_planner_private.generate_evening_routines('2027-03-14 21:00:00+00'); IF n<>3 THEN RAISE EXCEPTION 'DST evening count %',n; END IF;
 IF NOT EXISTS(SELECT FROM public.bb_planner_completions WHERE item_id=first_item) THEN RAISE EXCEPTION 'History lost'; END IF;
 IF EXISTS(SELECT FROM public.bb_planner_completions c JOIN bb_planner_private.routine_occurrences o ON o.item_id=c.item_id WHERE o.evening_date='2027-03-14') THEN RAISE EXCEPTION 'Completion copied'; END IF;
 IF (SELECT count(*) FROM public.bb_planner_items)<>before_items+6 THEN RAISE EXCEPTION 'Unexpected item changes'; END IF;
 IF EXISTS(SELECT FROM bb_planner_private.routine_occurrences o JOIN bb_planner_private.routine_templates t ON t.id=o.template_id JOIN public.bb_planner_items i ON i.id=o.item_id WHERE o.evening_date IN ('2027-03-13','2027-03-14') AND (i.completion_mode<>t.completion_mode OR (SELECT array_agg(a.assignee_id ORDER BY a.assignee_id) FROM public.bb_planner_assignments a WHERE a.item_id=i.id) IS DISTINCT FROM t.assignee_ids)) THEN RAISE EXCEPTION 'Assignment mismatch'; END IF;
 UPDATE bb_planner_private.routines SET enabled=false;
 n:=bb_planner_private.generate_evening_routines('2027-03-15 21:00:00+00'); IF n<>0 THEN RAISE EXCEPTION 'Disabled generated'; END IF;
 RAISE NOTICE 'PASS: ACLs, before/at evening, retry idempotence, DST, assignments, fresh completion state, preserved history, disable';
END $test$;
ROLLBACK;
