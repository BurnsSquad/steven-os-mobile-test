-- Usernames are labels/login handles; UUID memberships remain authoritative.
BEGIN;
CREATE TABLE public.bb_planner_profiles (
 user_id uuid PRIMARY KEY,
 household_id uuid NOT NULL,
 username text NOT NULL CHECK(username ~ '^[A-Za-z][A-Za-z0-9_]{2,23}$'),
 username_key text GENERATED ALWAYS AS (lower(username)) STORED,
 updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(household_id,user_id) REFERENCES public.bb_planner_members(household_id,user_id)
);
CREATE UNIQUE INDEX bb_planner_username_unique ON public.bb_planner_profiles(username_key);
CREATE INDEX bb_planner_profiles_household ON public.bb_planner_profiles(household_id,user_id);
ALTER TABLE public.bb_planner_profiles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bb_planner_profiles FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.bb_planner_profiles TO authenticated;
-- Only the server-side verified-password endpoint may write handles.
GRANT SELECT,INSERT ON public.bb_planner_profiles TO service_role;
GRANT UPDATE(username,updated_at) ON public.bb_planner_profiles TO service_role;
CREATE POLICY planner_profile_household_read ON public.bb_planner_profiles FOR SELECT TO authenticated
 USING(household_id IN (SELECT household_id FROM public.bb_planner_members WHERE user_id=(SELECT auth.uid())));
COMMIT;
