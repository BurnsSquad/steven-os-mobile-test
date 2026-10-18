-- Isolated finance reference/version store. No personal values in migration/source.
CREATE TABLE public.bb_finance_records (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), household_id uuid NOT NULL REFERENCES public.bb_planner_households(id),
 entity_key text NOT NULL,kind text NOT NULL CHECK(kind IN ('handoff','account','bill_instance','credit_card','installment','payment_arrangement','paycheck','check_plan','rule','confirmation')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0), payload jsonb NOT NULL CHECK(jsonb_typeof(payload)='object'),
 effective_start date NOT NULL, effective_end date, status text NOT NULL CHECK(status IN ('reference','active','inactive','superseded')),
 is_current boolean NOT NULL DEFAULT true, superseded_by uuid REFERENCES public.bb_finance_records(id) DEFERRABLE INITIALLY DEFERRED,
 source text NOT NULL, verified_at timestamptz, needs_confirmation boolean NOT NULL DEFAULT true,notes text NOT NULL DEFAULT '',created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(household_id,entity_key,version)
);
CREATE UNIQUE INDEX bb_finance_current ON public.bb_finance_records(household_id,entity_key) WHERE is_current;
CREATE INDEX bb_finance_household ON public.bb_finance_records(household_id,kind);
CREATE INDEX bb_finance_superseded ON public.bb_finance_records(superseded_by);
ALTER TABLE public.bb_finance_records ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bb_finance_records FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.bb_finance_records TO authenticated;
CREATE POLICY finance_parent_read ON public.bb_finance_records FOR SELECT TO authenticated USING(household_id IN (SELECT household_id FROM public.bb_planner_members WHERE user_id=(SELECT auth.uid()) AND member_role='adult'));
-- Initial handoff is an attributed reference, not a bank reconciliation. No client writes yet.
NOTIFY pgrst,'reload schema';
