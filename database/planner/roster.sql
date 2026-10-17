-- Additive member directory for authenticated members of the same household.
-- No emails, names, Auth table access, policy changes or new executor rights.
BEGIN;
CREATE FUNCTION bb_planner_private.household_roster(h uuid)
RETURNS TABLE(user_id uuid, member_role text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM bb_planner_private.require_member(h);
 RETURN QUERY SELECT m.user_id,m.member_role FROM public.bb_planner_members m
 WHERE m.household_id=h ORDER BY m.user_id;
END $$;
GRANT CREATE ON SCHEMA bb_planner_private TO bb_planner_executor;
ALTER FUNCTION bb_planner_private.household_roster(uuid) OWNER TO bb_planner_executor;
REVOKE CREATE ON SCHEMA bb_planner_private FROM bb_planner_executor;
REVOKE ALL ON FUNCTION bb_planner_private.household_roster(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION bb_planner_private.household_roster(uuid) TO authenticated;
CREATE FUNCTION public.bb_planner_roster(h uuid)
RETURNS TABLE(user_id uuid,member_role text)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
 SELECT * FROM bb_planner_private.household_roster(h)
$$;
REVOKE ALL ON FUNCTION public.bb_planner_roster(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.bb_planner_roster(uuid) TO authenticated;
COMMIT;
