-- Additive covering indexes for only the new planner foreign keys.
BEGIN;
CREATE INDEX bb_planner_items_creator_fk ON public.bb_planner_items(household_id,created_by);
CREATE INDEX bb_planner_assignments_item_fk ON public.bb_planner_assignments(item_id,household_id);
CREATE INDEX bb_planner_assignments_member_fk ON public.bb_planner_assignments(household_id,assignee_id);
CREATE INDEX bb_planner_completions_item_fk ON public.bb_planner_completions(item_id,household_id);
CREATE INDEX bb_planner_completions_actor_fk ON public.bb_planner_completions(household_id,actor_id);
CREATE INDEX bb_planner_events_item_fk ON public.bb_planner_events(item_id,household_id);
CREATE INDEX bb_planner_events_actor_fk ON public.bb_planner_events(household_id,actor_id);
COMMIT;
