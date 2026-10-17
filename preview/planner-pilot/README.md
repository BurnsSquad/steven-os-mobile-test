# Household pilot v135

Separate email/password pilot; v134 fictional preview and stable root index are unchanged.

- Provider `/auth/v1/user` verifies sign-in identity; memory-only access/refresh tokens.
- The actor's own RLS-filtered membership determines the household and role. Zero/multiple memberships fail closed; there is no role picker or embedded personal identity mapping.
- Member-only `bb_planner_roster` returns IDs/roles, never emails or profile metadata. Private helper uses the existing NOLOGIN executor and checks membership before reading; public wrapper is an invoker. No additional table rights or policy broadening.
- Names are deliberately generic: You, Adult/Child plus directory position. Household display names and child onboarding are future work.
- Same transactional create/rename/assign/complete RPCs and 15-second visible-tab refresh.
- Recovery remains organizer-assisted through supported provider controls; this page does not send reset/invitation emails or auto-create accounts. Review recovery and delivery before relying on the pilot.
- Finance/original-dashboard data is not imported. No production promotion.

Validation: `node scripts/planner-pilot-api.test.mjs` (6 mock-transport cases) and `node scripts/planner-pilot-smoke.cjs` (desktop/mobile contexts, mocked Auth/API, no actual credentials). Hosted SQL-role directory checks are distinct from actual provider JWT/browser acceptance, which the account owners must perform.
