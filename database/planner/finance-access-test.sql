-- Hosted SQL-role verification; no real JWT/password/session impersonation claim.
BEGIN;
DO $test$
DECLARE h uuid; a uuid; c uuid; outsider uuid; n bigint; expected bigint;
BEGIN
 SELECT household_id INTO STRICT h FROM bb_planner_private.routines WHERE routine_key='prepare_for_tomorrow_v1';
 SELECT count(*) INTO expected FROM public.bb_finance_records WHERE household_id=h;
 IF expected=0 THEN RAISE EXCEPTION 'Missing reference'; END IF;
 SELECT user_id INTO a FROM public.bb_planner_members WHERE household_id=h AND member_role='adult' LIMIT 1;
 SELECT user_id INTO c FROM public.bb_planner_members WHERE household_id=h AND member_role='child' LIMIT 1;
 SELECT user_id INTO outsider FROM public.bb_planner_members m WHERE NOT EXISTS(SELECT FROM public.bb_planner_members x WHERE x.household_id=h AND x.user_id=m.user_id) LIMIT 1;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);EXECUTE 'SET LOCAL ROLE authenticated';
 SELECT count(*) INTO n FROM public.bb_finance_records WHERE household_id=h;IF n<>expected THEN RAISE EXCEPTION 'Adult missing records'; END IF;
 BEGIN UPDATE public.bb_finance_records SET needs_confirmation=false WHERE household_id=h;RAISE EXCEPTION 'Unexpected direct write';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);SELECT count(*) INTO n FROM public.bb_finance_records;IF n<>0 THEN RAISE EXCEPTION 'Child finance leak';END IF;
 PERFORM set_config('request.jwt.claim.sub',outsider::text,true);SELECT count(*) INTO n FROM public.bb_finance_records WHERE household_id=h;IF n<>0 THEN RAISE EXCEPTION 'Foreign household finance leak';END IF;
 EXECUTE 'SET LOCAL ROLE postgres';
 IF has_table_privilege('anon','public.bb_finance_records','SELECT') THEN RAISE EXCEPTION 'Anonymous finance access'; END IF;
 IF EXISTS(SELECT FROM public.bb_finance_records WHERE household_id=h AND (source='' OR effective_start IS NULL OR NOT needs_confirmation)) THEN RAISE EXCEPTION 'Source/confirmation metadata';END IF;
 RAISE NOTICE 'PASS adult read, child/outsider/anon denial, no direct writes, provenance and confirmation flags';
END $test$;
ROLLBACK;
