-- Additive adult-only manual review workflow; imported references and original OS are preserved.
CREATE TABLE public.bb_finance_check_plans(
 id uuid PRIMARY KEY,household_id uuid NOT NULL,created_by uuid NOT NULL,
 version integer NOT NULL DEFAULT 1 CHECK(version>0),inputs jsonb NOT NULL,calculation jsonb NOT NULL,
 status text NOT NULL CHECK(status IN('draft','approved')),source_fingerprint text NOT NULL,
 approved_by uuid,approved_at timestamptz,created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(household_id,created_by) REFERENCES public.bb_planner_members(household_id,user_id),
 FOREIGN KEY(household_id,approved_by) REFERENCES public.bb_planner_members(household_id,user_id));
CREATE INDEX finance_plan_household ON public.bb_finance_check_plans(household_id,updated_at);
CREATE INDEX finance_plan_creator ON public.bb_finance_check_plans(household_id,created_by);
CREATE INDEX finance_plan_approver ON public.bb_finance_check_plans(household_id,approved_by);
CREATE TABLE public.bb_finance_changes(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),household_id uuid NOT NULL REFERENCES public.bb_planner_households(id),
 actor_id uuid NOT NULL,target_id uuid NOT NULL,action text NOT NULL CHECK(action IN('fact_revised','plan_saved','plan_approved')),
 before_state jsonb,after_state jsonb NOT NULL,reason text NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(household_id,actor_id) REFERENCES public.bb_planner_members(household_id,user_id));
CREATE INDEX finance_change_target ON public.bb_finance_changes(household_id,target_id,created_at);
CREATE INDEX finance_change_actor ON public.bb_finance_changes(household_id,actor_id);
ALTER TABLE public.bb_finance_check_plans ENABLE ROW LEVEL SECURITY;ALTER TABLE public.bb_finance_changes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bb_finance_check_plans,public.bb_finance_changes FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.bb_finance_check_plans,public.bb_finance_changes TO authenticated;
CREATE POLICY finance_plan_parent ON public.bb_finance_check_plans FOR SELECT TO authenticated USING(EXISTS(SELECT FROM public.bb_planner_members m WHERE m.household_id=bb_finance_check_plans.household_id AND m.user_id=(SELECT auth.uid()) AND m.member_role='adult'));
CREATE POLICY finance_change_parent ON public.bb_finance_changes FOR SELECT TO authenticated USING(EXISTS(SELECT FROM public.bb_planner_members m WHERE m.household_id=bb_finance_changes.household_id AND m.user_id=(SELECT auth.uid()) AND m.member_role='adult'));
CREATE ROLE bb_finance_writer NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT bb_finance_writer TO postgres;GRANT USAGE ON SCHEMA public,bb_planner_private TO bb_finance_writer;
GRANT SELECT ON public.bb_planner_members,public.bb_finance_records,public.bb_finance_check_plans,public.bb_finance_changes TO bb_finance_writer;
GRANT INSERT ON public.bb_finance_records,public.bb_finance_check_plans,public.bb_finance_changes TO bb_finance_writer;
GRANT UPDATE(effective_end,status,is_current,superseded_by) ON public.bb_finance_records TO bb_finance_writer;
GRANT UPDATE(inputs,calculation,version,status,source_fingerprint,approved_by,approved_at,updated_at) ON public.bb_finance_check_plans TO bb_finance_writer;
CREATE POLICY finance_writer_members ON public.bb_planner_members FOR SELECT TO bb_finance_writer USING(true);
CREATE POLICY finance_writer_facts_read ON public.bb_finance_records FOR SELECT TO bb_finance_writer USING(true);
CREATE POLICY finance_writer_facts_insert ON public.bb_finance_records FOR INSERT TO bb_finance_writer WITH CHECK(true);
CREATE POLICY finance_writer_facts_update ON public.bb_finance_records FOR UPDATE TO bb_finance_writer USING(true) WITH CHECK(true);
CREATE POLICY finance_writer_plans_read ON public.bb_finance_check_plans FOR SELECT TO bb_finance_writer USING(true);
CREATE POLICY finance_writer_plans_insert ON public.bb_finance_check_plans FOR INSERT TO bb_finance_writer WITH CHECK(true);
CREATE POLICY finance_writer_plans_update ON public.bb_finance_check_plans FOR UPDATE TO bb_finance_writer USING(true) WITH CHECK(true);
CREATE POLICY finance_writer_changes_read ON public.bb_finance_changes FOR SELECT TO bb_finance_writer USING(true);
CREATE POLICY finance_writer_changes_insert ON public.bb_finance_changes FOR INSERT TO bb_finance_writer WITH CHECK(true);
GRANT EXECUTE ON FUNCTION bb_planner_private.actor_uid(),bb_planner_private.require_member(uuid) TO bb_finance_writer;

CREATE FUNCTION bb_planner_private.finance_calculate(h uuid,p jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE account public.bb_finance_records;r public.bb_finance_records;k text;v jsonb;start_day date;next_day date;asof date;amount bigint;cash bigint;living bigint;buffer bigint;protected bigint;optional bigint;bills bigint:=0;minimums bigint:=0;required bigint;remaining bigint;fingerprint text;blocks jsonb:='[]';warnings jsonb:='[]';items jsonb:='[]';minimum_buffer bigint;account_name text;account_key text;paid boolean;deducted boolean;
BEGIN
 IF bb_planner_private.require_member(h)<>'adult' THEN RAISE EXCEPTION 'Adults only' USING ERRCODE='42501';END IF;
 IF p IS NULL OR jsonb_typeof(p)<>'object' OR length(p::text)>12000 THEN RAISE EXCEPTION 'Invalid plan' USING ERRCODE='22023';END IF;
 FOR k,v IN SELECT * FROM jsonb_each(p) LOOP
  IF k NOT IN('name','account_key','received_on','next_payday','cash_as_of','available_cash_cents','protected_other_cents','food_cents','gas_cents','laundry_cents','other_living_cents','buffer_cents','utilization_cents','savings_cents','extra_debt_cents','cash_confirmed','living_confirmed','obligations_reviewed','buffer_exception','source_note') THEN RAISE EXCEPTION 'Unknown plan field' USING ERRCODE='22023';END IF;
  IF k LIKE '%\_cents' ESCAPE '\' AND v<>'null'::jsonb AND (jsonb_typeof(v)<>'number' OR v::text!~(CASE WHEN k='available_cash_cents' THEN '^-?\d+$' ELSE '^\d+$' END) OR abs((v::text)::numeric)>100000000000) THEN RAISE EXCEPTION 'Amounts must be nonnegative integer cents' USING ERRCODE='22023';END IF;
  IF k IN('cash_confirmed','living_confirmed','obligations_reviewed','buffer_exception') AND jsonb_typeof(v)<>'boolean' THEN RAISE EXCEPTION 'Invalid confirmation' USING ERRCODE='22023';END IF;
 END LOOP;
 IF length(btrim(coalesce(p->>'name',''))) NOT BETWEEN 1 AND 160 OR length(coalesce(p->>'source_note',''))>2000 THEN RAISE EXCEPTION 'Name required' USING ERRCODE='22023';END IF;
 IF coalesce(p->>'received_on','')!~'^\d{4}-\d{2}-\d{2}$' OR coalesce(p->>'next_payday','')!~'^\d{4}-\d{2}-\d{2}$' OR coalesce(p->>'cash_as_of','')!~'^\d{4}-\d{2}-\d{2}$' THEN RAISE EXCEPTION 'Use explicit ISO dates' USING ERRCODE='22023';END IF;
 BEGIN start_day:=(p->>'received_on')::date;next_day:=(p->>'next_payday')::date;asof:=(p->>'cash_as_of')::date;EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'Invalid dates' USING ERRCODE='22023';END;
 IF start_day IS NULL OR next_day IS NULL OR asof IS NULL OR next_day<=start_day OR next_day-start_day>62 OR asof<start_day OR asof>=next_day OR asof>(now() AT TIME ZONE 'America/New_York')::date THEN RAISE EXCEPTION 'Use a received payday and valid as-of date inside the pay window' USING ERRCODE='22023';END IF;
 account_key:=p->>'account_key';SELECT * INTO account FROM public.bb_finance_records WHERE household_id=h AND entity_key=account_key AND kind='account' AND is_current AND status<>'inactive';
 IF NOT FOUND OR (account.payload->>'household_usable') IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Choose a household spending account; protected/business accounts are excluded' USING ERRCODE='22023';END IF;
 account_name:=account.payload->>'name';minimum_buffer:=nullif(account.payload->>'buffer_min_cents','')::bigint;
 cash:=(p->>'available_cash_cents')::bigint;protected:=(p->>'protected_other_cents')::bigint;buffer:=(p->>'buffer_cents')::bigint;
 living:=(p->>'food_cents')::bigint+(p->>'gas_cents')::bigint+(p->>'laundry_cents')::bigint+(p->>'other_living_cents')::bigint;
 optional:=coalesce((p->>'utilization_cents')::bigint,0)+coalesce((p->>'savings_cents')::bigint,0)+coalesce((p->>'extra_debt_cents')::bigint,0);
 IF cash IS NULL OR protected IS NULL OR living IS NULL OR buffer IS NULL THEN blocks:=blocks||jsonb_build_array('Cash, protected money, living and buffer amounts all need confirmation.');END IF;
 IF (p->>'cash_confirmed') IS DISTINCT FROM 'true' THEN blocks:=blocks||jsonb_build_array('Confirm received, usable cash. Future deposits, credit and unreleased savings are excluded.');END IF;
 IF (p->>'living_confirmed') IS DISTINCT FROM 'true' THEN blocks:=blocks||jsonb_build_array('Review realistic remaining living needs and the checking buffer.');END IF;
 IF (p->>'obligations_reviewed') IS DISTINCT FROM 'true' THEN blocks:=blocks||jsonb_build_array('Confirm the dated obligation list is complete, including minimum debt once and temporary arrangements.');END IF;
 IF buffer<minimum_buffer THEN
  warnings:=warnings||jsonb_build_array('Chosen buffer is below the account reference minimum.');
  IF (p->>'buffer_exception') IS DISTINCT FROM 'true' OR length(btrim(coalesce(p->>'source_note','')))<10 THEN blocks:=blocks||jsonb_build_array('Explain and acknowledge the reduced buffer before approving.');END IF;
 END IF;
 FOR r IN SELECT * FROM public.bb_finance_records WHERE household_id=h AND kind='bill_instance' AND is_current AND status IN('active','reference') ORDER BY entity_key LOOP
  IF r.payload->>'due_date' IS NOT NULL AND ((r.payload->>'due_date')::date<start_day OR (r.payload->>'due_date')::date>=next_day) THEN CONTINUE;END IF;
  IF (CASE WHEN nullif(r.payload->>'account_key','') IS NOT NULL THEN r.payload->>'account_key'<>account_key ELSE coalesce(r.payload->>'account','')<>account_name END) THEN
   IF NOT EXISTS(SELECT FROM public.bb_finance_records a WHERE a.household_id=h AND a.is_current AND a.kind='account' AND (a.entity_key=r.payload->>'account_key' OR a.payload->>'name'=r.payload->>'account')) THEN blocks:=blocks||jsonb_build_array('Resolve the account for bill: '||coalesce(r.payload->>'name',r.entity_key));END IF;
   CONTINUE;
  END IF;
  IF r.effective_start>asof THEN blocks:=blocks||jsonb_build_array('A bill source is newer than this cash snapshot: '||coalesce(r.payload->>'name',r.entity_key));END IF;
  IF r.payload->>'due_date' IS NULL THEN blocks:=blocks||jsonb_build_array('Confirm due date for '||coalesce(r.payload->>'name',r.entity_key));CONTINUE;END IF;
  amount:=(r.payload->>'amount_cents')::bigint;
  IF amount IS NULL THEN blocks:=blocks||jsonb_build_array('Confirm amount for '||coalesce(r.payload->>'name',r.entity_key));CONTINUE;END IF;
  paid:=coalesce(r.payload->>'payment_status' IN('paid','reconciled') AND NOT r.needs_confirmation AND r.status='active',false);deducted:=coalesce(coalesce(r.payload->>'already_deducted','false')='true' AND r.payload->>'deducted_as_of'=asof::text AND NOT r.needs_confirmation AND r.status='active',false);IF r.payload->>'already_deducted'='true' AND NOT deducted THEN blocks:=blocks||jsonb_build_array('Reconcile deduction against this exact cash snapshot: '||coalesce(r.payload->>'name',r.entity_key));END IF;
  IF r.needs_confirmation OR r.status<>'active' OR coalesce(r.payload->>'certainty','exact') NOT IN('exact','confirmed') OR coalesce(r.payload->>'payment_status','unknown') IN('expected','unknown','needs_confirmation') THEN blocks:=blocks||jsonb_build_array('Review current amount/date/status: '||coalesce(r.payload->>'name',r.entity_key));END IF;
  items:=items||jsonb_build_array(jsonb_build_object('id',r.id,'version',r.version,'name',r.payload->>'name','due_date',r.payload->>'due_date','amount_cents',amount,'payment_status',r.payload->>'payment_status','account',account_name,'paid',paid,'already_deducted',deducted,'class',coalesce(r.payload->>'allocation_class','bill'),'needs_confirmation',r.needs_confirmation));
  IF NOT paid AND NOT deducted THEN IF r.payload->>'allocation_class'='debt_minimum' THEN minimums:=minimums+amount;ELSE bills:=bills+amount;END IF;END IF;
 END LOOP;
 SELECT md5(coalesce(string_agg(id::text||':'||version::text,',' ORDER BY entity_key),'')) INTO fingerprint FROM public.bb_finance_records WHERE household_id=h AND is_current;
 required:=bills+minimums;remaining:=cash-protected-required-living-buffer;
 IF remaining<0 THEN blocks:=blocks||jsonb_build_array('Required needs exceed available cash. Resolve the shortfall before approving.');END IF;
 IF optional>greatest(coalesce(remaining,0),0) THEN blocks:=blocks||jsonb_build_array('Optional allocations exceed money remaining after required needs and stability.');END IF;
 IF blocks<>'[]'::jsonb THEN warnings:=warnings||jsonb_build_array('Uncertainty blocks approval and optional scenarios.');END IF;
 RETURN jsonb_build_object('window_start',start_day,'window_end',next_day-1,'cash_as_of',asof,'account',account_name,'cash_cents',cash,'protected_cents',protected,'bills_cents',bills,'minimums_cents',minimums,'required_cents',required,'living_cents',living,'buffer_cents',buffer,'optional_cents',optional,'base_remaining_cents',remaining,'unassigned_cents',remaining-optional,'items',items,'blockers',blocks,'warnings',warnings,'source_fingerprint',fingerprint,'scenarios',CASE WHEN blocks='[]'::jsonb AND remaining IS NOT NULL THEN jsonb_build_array(jsonb_build_object('name','Safe','optional_capacity_cents',0,'unassigned_cents',remaining,'reason','Protect living and the selected buffer; keep the remainder unassigned.'),jsonb_build_object('name','Balanced','optional_capacity_cents',remaining/2,'unassigned_cents',remaining-remaining/2,'reason','Illustrative half of surplus reserved for an optional choice; no payment is selected.'),jsonb_build_object('name','Aggressive','optional_capacity_cents',remaining,'unassigned_cents',0,'reason','Illustrative full surplus capacity; no extra cushion beyond the selected buffer. No payment is selected.')) ELSE '[]'::jsonb END);
END $$;

CREATE FUNCTION bb_planner_private.finance_plan_save(h uuid,i uuid,v integer,p jsonb,approved boolean,fingerprint text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE old public.bb_finance_check_plans;next public.bb_finance_check_plans;calc jsonb;actor uuid:=bb_planner_private.actor_uid();
BEGIN
 IF bb_planner_private.require_member(h)<>'adult' THEN RAISE EXCEPTION 'Adults only' USING ERRCODE='42501';END IF;
 IF i IS NULL OR approved IS NULL OR length(btrim(coalesce(p->>'source_note','')))<10 THEN RAISE EXCEPTION 'Explain the source/context in at least ten characters' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(h::text||':finance',0));
 SELECT * INTO old FROM public.bb_finance_check_plans WHERE id=i FOR UPDATE;
 IF FOUND THEN IF old.household_id<>h THEN RAISE EXCEPTION 'Unavailable plan' USING ERRCODE='42501';END IF;IF v IS NULL OR old.version<>v THEN RAISE EXCEPTION 'Plan changed elsewhere' USING ERRCODE='40001';END IF;
 ELSE IF v IS NOT NULL THEN RAISE EXCEPTION 'Unavailable plan' USING ERRCODE='42501';END IF;END IF;
 calc:=bb_planner_private.finance_calculate(h,p);
 IF fingerprint IS DISTINCT FROM calc->>'source_fingerprint' THEN RAISE EXCEPTION 'Source facts changed; preview again' USING ERRCODE='40001';END IF;
 IF approved AND jsonb_array_length(calc->'blockers')>0 THEN RAISE EXCEPTION 'Resolve confirmations before approval' USING ERRCODE='55000';END IF;
 IF old.id IS NULL THEN INSERT INTO public.bb_finance_check_plans(id,household_id,created_by,inputs,calculation,status,source_fingerprint,approved_by,approved_at) VALUES(i,h,actor,p,calc,CASE WHEN approved THEN 'approved' ELSE 'draft' END,fingerprint,CASE WHEN approved THEN actor END,CASE WHEN approved THEN clock_timestamp() END) RETURNING * INTO next;
 ELSE UPDATE public.bb_finance_check_plans SET version=version+1,inputs=p,calculation=calc,status=CASE WHEN approved THEN 'approved' ELSE 'draft' END,source_fingerprint=fingerprint,approved_by=CASE WHEN approved THEN actor END,approved_at=CASE WHEN approved THEN clock_timestamp() END,updated_at=clock_timestamp() WHERE id=i RETURNING * INTO next;END IF;
 INSERT INTO public.bb_finance_changes(household_id,actor_id,target_id,action,before_state,after_state,reason) VALUES(h,actor,i,CASE WHEN approved THEN 'plan_approved' ELSE 'plan_saved' END,CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(next),p->>'source_note');RETURN to_jsonb(next);
END $$;

CREATE FUNCTION bb_planner_private.finance_fact_revise(h uuid,i uuid,v integer,patch jsonb,active boolean,confirmed boolean,effective date,reason text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE old public.bb_finance_records;next public.bb_finance_records;k text;value jsonb;allowed text[];body jsonb;actor uuid:=bb_planner_private.actor_uid();
BEGIN
 IF bb_planner_private.require_member(h)<>'adult' THEN RAISE EXCEPTION 'Adults only' USING ERRCODE='42501';END IF;
 IF patch IS NULL OR jsonb_typeof(patch)<>'object' OR length(patch::text)>12000 OR active IS NULL OR confirmed IS NULL OR effective IS NULL OR effective>(now() AT TIME ZONE 'America/New_York')::date OR length(btrim(coalesce(reason,''))) NOT BETWEEN 10 AND 2000 THEN RAISE EXCEPTION 'Invalid revision or source explanation' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(h::text||':finance',0));SELECT * INTO old FROM public.bb_finance_records WHERE id=i FOR UPDATE;
 IF NOT FOUND OR old.household_id<>h THEN RAISE EXCEPTION 'Record unavailable' USING ERRCODE='42501';END IF;
 IF old.version<>v OR v IS NULL OR NOT old.is_current THEN RAISE EXCEPTION 'Record changed elsewhere' USING ERRCODE='40001';END IF;
 IF effective<old.effective_start THEN RAISE EXCEPTION 'Effective date predates this source; keep history intact' USING ERRCODE='22023';END IF;
 allowed:=CASE old.kind WHEN 'account' THEN ARRAY['name','purpose','current_balance_cents','available_balance_cents','buffer_min_cents','buffer_target_cents'] WHEN 'bill_instance' THEN ARRAY['name','account','account_key','due_date','amount_cents','payment_status','certainty','allocation_class','already_deducted','deducted_as_of'] WHEN 'credit_card' THEN ARRAY['name','balance_cents','limit_cents','minimum_cents','due_date','planned_payment_cents','reporting_window'] WHEN 'installment' THEN ARRAY['name','payment_cents','next_date','payoff_cents','payment_status'] WHEN 'payment_arrangement' THEN ARRAY['name','installment_cents','remaining_balance_cents','remaining_approximate','next_decision'] WHEN 'confirmation' THEN ARRAY['title','resolved'] WHEN 'rule' THEN CASE WHEN old.entity_key='living' THEN ARRAY['food_cents','gas_cents','laundry_cents','total_cents'] END END;
 IF allowed IS NULL THEN RAISE EXCEPTION 'This source document/rule is immutable; revise supported facts instead' USING ERRCODE='42501';END IF;
 FOR k,value IN SELECT * FROM jsonb_each(patch) LOOP
  IF NOT k=ANY(allowed) THEN RAISE EXCEPTION 'Unsupported fact field' USING ERRCODE='22023';END IF;
  IF value='null'::jsonb THEN CONTINUE;END IF;
  IF k LIKE '%\_cents' ESCAPE '\' THEN IF jsonb_typeof(value)<>'number' OR value::text!~(CASE WHEN old.kind='account' AND k IN('current_balance_cents','available_balance_cents') THEN '^-?\d+$' ELSE '^\d+$' END) OR abs((value::text)::numeric)>100000000000 THEN RAISE EXCEPTION 'Use nonnegative integer cents' USING ERRCODE='22023';END IF;
  ELSIF k IN('remaining_approximate','resolved','already_deducted') THEN IF jsonb_typeof(value)<>'boolean' THEN RAISE EXCEPTION 'Invalid flag' USING ERRCODE='22023';END IF;
  ELSE IF jsonb_typeof(value)<>'string' OR length(value#>>'{}')>1000 THEN RAISE EXCEPTION 'Invalid text' USING ERRCODE='22023';END IF;
   IF k IN('due_date','next_date','deducted_as_of') THEN BEGIN PERFORM (value#>>'{}')::date;EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'Invalid date' USING ERRCODE='22023';END;END IF;
  END IF;
 END LOOP;
 body:=old.payload||patch;IF patch?'account' AND NOT patch?'account_key' THEN body:=body-'account_key';END IF;body:=body||jsonb_build_object('source_type','family_confirmation','source_timestamp',clock_timestamp(),'context_note',reason);
 IF old.kind IN('account','bill_instance','credit_card','installment','payment_arrangement') AND length(btrim(coalesce(body->>'name',''))) NOT BETWEEN 1 AND 160 THEN RAISE EXCEPTION 'Name required' USING ERRCODE='22023';END IF;
 IF old.kind='account' AND EXISTS(SELECT FROM public.bb_finance_records a WHERE a.household_id=h AND a.kind='account' AND a.is_current AND a.id<>i AND a.payload->>'name'=body->>'name') THEN RAISE EXCEPTION 'Use a distinct account name' USING ERRCODE='22023';END IF;
 IF body->>'allocation_class' IS NOT NULL AND body->>'allocation_class' NOT IN('bill','debt_minimum') THEN RAISE EXCEPTION 'Invalid allocation class' USING ERRCODE='22023';END IF;
 IF old.kind='bill_instance' AND coalesce(body->>'payment_status','needs_confirmation') NOT IN('confirmed','expected','scheduled','pending','paid','reconciled','needs_confirmation','planned','autopay_confirmed','unknown') THEN RAISE EXCEPTION 'Invalid payment state' USING ERRCODE='22023';END IF;
 IF old.entity_key='living' THEN body:=body||jsonb_build_object('total_cents',(body->>'food_cents')::bigint+(body->>'gas_cents')::bigint+(body->>'laundry_cents')::bigint);END IF;
 UPDATE public.bb_finance_records SET is_current=false,status='superseded',effective_end=effective WHERE id=i;
 INSERT INTO public.bb_finance_records(household_id,entity_key,kind,version,payload,effective_start,status,is_current,source,verified_at,needs_confirmation,notes) VALUES(h,old.entity_key,old.kind,old.version+1,body,effective,CASE WHEN NOT active THEN 'inactive' WHEN confirmed THEN 'active' ELSE 'reference' END,true,'Family confirmation',CASE WHEN confirmed THEN clock_timestamp() END,NOT confirmed,reason) RETURNING * INTO next;
 UPDATE public.bb_finance_records SET superseded_by=next.id WHERE id=i;
 INSERT INTO public.bb_finance_changes(household_id,actor_id,target_id,action,before_state,after_state,reason) VALUES(h,actor,next.id,'fact_revised',to_jsonb(old),to_jsonb(next),reason);RETURN to_jsonb(next);
END $$;

GRANT CREATE ON SCHEMA bb_planner_private TO bb_finance_writer;
ALTER FUNCTION bb_planner_private.finance_calculate(uuid,jsonb) OWNER TO bb_finance_writer;
ALTER FUNCTION bb_planner_private.finance_plan_save(uuid,uuid,integer,jsonb,boolean,text) OWNER TO bb_finance_writer;
ALTER FUNCTION bb_planner_private.finance_fact_revise(uuid,uuid,integer,jsonb,boolean,boolean,date,text) OWNER TO bb_finance_writer;
REVOKE CREATE ON SCHEMA bb_planner_private FROM bb_finance_writer;
REVOKE ALL ON FUNCTION bb_planner_private.finance_calculate(uuid,jsonb),bb_planner_private.finance_plan_save(uuid,uuid,integer,jsonb,boolean,text),bb_planner_private.finance_fact_revise(uuid,uuid,integer,jsonb,boolean,boolean,date,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION bb_planner_private.finance_calculate(uuid,jsonb),bb_planner_private.finance_plan_save(uuid,uuid,integer,jsonb,boolean,text),bb_planner_private.finance_fact_revise(uuid,uuid,integer,jsonb,boolean,boolean,date,text) TO authenticated;
CREATE FUNCTION public.bb_finance_preview(h uuid,p jsonb) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.finance_calculate(h,p) $$;
CREATE FUNCTION public.bb_finance_plan_save(h uuid,i uuid,v integer,p jsonb,approved boolean,fingerprint text) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.finance_plan_save(h,i,v,p,approved,fingerprint) $$;
CREATE FUNCTION public.bb_finance_fact_revise(h uuid,i uuid,v integer,patch jsonb,active boolean,confirmed boolean,effective date,reason text) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.finance_fact_revise(h,i,v,patch,active,confirmed,effective,reason) $$;
REVOKE ALL ON FUNCTION public.bb_finance_preview(uuid,jsonb),public.bb_finance_plan_save(uuid,uuid,integer,jsonb,boolean,text),public.bb_finance_fact_revise(uuid,uuid,integer,jsonb,boolean,boolean,date,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.bb_finance_preview(uuid,jsonb),public.bb_finance_plan_save(uuid,uuid,integer,jsonb,boolean,text),public.bb_finance_fact_revise(uuid,uuid,integer,jsonb,boolean,boolean,date,text) TO authenticated;
NOTIFY pgrst,'reload schema';

CREATE FUNCTION bb_planner_private.finance_bill_create(h uuid,i uuid,p jsonb,effective date,confirmed boolean,reason text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE next public.bb_finance_records;existing public.bb_finance_records;a public.bb_finance_records;k text;v jsonb;body jsonb;actor uuid:=bb_planner_private.actor_uid();
BEGIN
 IF bb_planner_private.require_member(h)<>'adult' THEN RAISE EXCEPTION 'Adults only' USING ERRCODE='42501';END IF;
 IF i IS NULL OR confirmed IS NULL OR p IS NULL OR jsonb_typeof(p)<>'object' OR effective IS NULL OR effective>(now() AT TIME ZONE 'America/New_York')::date OR length(btrim(coalesce(reason,''))) NOT BETWEEN 10 AND 2000 OR length(btrim(coalesce(p->>'name',''))) NOT BETWEEN 1 AND 160 THEN RAISE EXCEPTION 'Invalid dated bill or source' USING ERRCODE='22023';END IF;
 FOR k,v IN SELECT * FROM jsonb_each(p) LOOP
  IF k NOT IN('name','account','due_date','amount_cents','payment_status','certainty','allocation_class','already_deducted','deducted_as_of') THEN RAISE EXCEPTION 'Invalid bill field' USING ERRCODE='22023';END IF;
  IF v='null'::jsonb THEN CONTINUE;END IF;
  IF k='amount_cents' THEN IF jsonb_typeof(v)<>'number' OR v::text!~'^\d+$' OR v::text::numeric>100000000000 THEN RAISE EXCEPTION 'Invalid cents' USING ERRCODE='22023';END IF;
  ELSIF k='already_deducted' THEN IF jsonb_typeof(v)<>'boolean' THEN RAISE EXCEPTION 'Invalid deduction flag' USING ERRCODE='22023';END IF;
  ELSIF jsonb_typeof(v)<>'string' OR length(v#>>'{}')>1000 THEN RAISE EXCEPTION 'Invalid bill text' USING ERRCODE='22023';END IF;
 END LOOP;
 IF p->>'deducted_as_of' IS NOT NULL THEN BEGIN PERFORM (p->>'deducted_as_of')::date;EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'Invalid snapshot date' USING ERRCODE='22023';END;END IF;
 IF p->>'due_date' IS NOT NULL THEN BEGIN PERFORM (p->>'due_date')::date;EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'Invalid due date' USING ERRCODE='22023';END;END IF;
 IF confirmed AND (p->>'due_date' IS NULL OR p->>'amount_cents' IS NULL) THEN RAISE EXCEPTION 'Confirmed bill needs date and amount' USING ERRCODE='22023';END IF;
 IF coalesce(p->>'payment_status','needs_confirmation') NOT IN('confirmed','expected','scheduled','pending','paid','reconciled','needs_confirmation','planned','autopay_confirmed','unknown') OR coalesce(p->>'allocation_class','bill') NOT IN('bill','debt_minimum') OR coalesce(p->>'certainty','expected') NOT IN('exact','confirmed','expected','approximate') THEN RAISE EXCEPTION 'Invalid bill status' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(h::text||':finance',0));
 SELECT * INTO a FROM public.bb_finance_records WHERE household_id=h AND kind='account' AND is_current AND status<>'inactive' AND payload->>'name'=p->>'account' AND payload->>'household_usable'='true';
 IF NOT FOUND THEN RAISE EXCEPTION 'Choose a household account' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(h::text||':finance',0));
 SELECT * INTO existing FROM public.bb_finance_records WHERE id=i;
 IF FOUND THEN IF existing.household_id=h AND existing.kind='bill_instance' AND existing.payload @> p AND existing.is_current AND existing.needs_confirmation=NOT confirmed AND existing.effective_start=effective AND existing.notes=reason THEN RETURN to_jsonb(existing);END IF;RAISE EXCEPTION 'Record already exists' USING ERRCODE='40001';END IF;
 body:=jsonb_build_object('payment_status','needs_confirmation','allocation_class','bill','certainty','expected')||p||jsonb_build_object('account_key',a.entity_key,'source_type','family_confirmation','source_timestamp',clock_timestamp(),'context_note',reason);
 INSERT INTO public.bb_finance_records(id,household_id,entity_key,kind,payload,effective_start,status,source,verified_at,needs_confirmation,notes) VALUES(i,h,'manual-bill-'||i::text,'bill_instance',body,effective,CASE WHEN confirmed THEN 'active' ELSE 'reference' END,'Family confirmation',CASE WHEN confirmed THEN clock_timestamp() END,NOT confirmed,reason) RETURNING * INTO next;
 INSERT INTO public.bb_finance_changes(household_id,actor_id,target_id,action,before_state,after_state,reason) VALUES(h,actor,i,'fact_revised',NULL,to_jsonb(next),reason);RETURN to_jsonb(next);
END $$;
GRANT CREATE ON SCHEMA bb_planner_private TO bb_finance_writer;
ALTER FUNCTION bb_planner_private.finance_bill_create(uuid,uuid,jsonb,date,boolean,text) OWNER TO bb_finance_writer;
REVOKE CREATE ON SCHEMA bb_planner_private FROM bb_finance_writer;
REVOKE ALL ON FUNCTION bb_planner_private.finance_bill_create(uuid,uuid,jsonb,date,boolean,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION bb_planner_private.finance_bill_create(uuid,uuid,jsonb,date,boolean,text) TO authenticated;
CREATE FUNCTION public.bb_finance_bill_create(h uuid,i uuid,p jsonb,effective date,confirmed boolean,reason text) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT bb_planner_private.finance_bill_create(h,i,p,effective,confirmed,reason) $$;
REVOKE ALL ON FUNCTION public.bb_finance_bill_create(uuid,uuid,jsonb,date,boolean,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.bb_finance_bill_create(uuid,uuid,jsonb,date,boolean,text) TO authenticated;
NOTIFY pgrst,'reload schema';
