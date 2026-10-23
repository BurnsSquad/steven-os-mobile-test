# v134 connected planner preview

Actual supported Supabase Auth password sign-in → verified returned user → private-schema exclusion check → own new-planner membership → planner RPCs → rendered shared data. This is separate from both prior previews and does not read or change stable/local Steven OS records or old bb_test_* tables.

Use saved fictional A/B/C credentials only. New planner mapping: A adult, B/C child; role authority comes from database membership. The account dropdown selects which real test identity signs in; it is not a view/role switch. Adult creation/assignment and child self-Activity creation use the five installed public RPCs. Neither editable metadata nor client-supplied roles authorize anything.

`config.mjs` in this public repository has no key. The dedicated Vercel deployment can supply its browser-intended publishable key asset, or the UI asks for the publishable key. Never supply a service/secret/admin key. Passwords, access tokens and refresh tokens stay in memory only, not localStorage/sessionStorage, logs, repository, screenshots or handoff artifacts. Reload requires sign-in. Active tabs refresh short-lived access tokens in memory; repeated401 retries are bounded. Sign-out clears local data even when server revocation cannot be confirmed.

List refreshes every15 seconds when visible and on visibility change/manual Refresh. Server versions protect rename/assignment; conflict refreshes and closes stale controls. Rename and reassignment are separate operations so one successful request cannot masquerade as a combined atomic edit. Contributions lock assignment on server. Shared partial-completion wording now explicitly says the user's own part is done and others remain.

The login flow probes private `actor_uid` with an Accept-Profile header and requires PGRST106 (unexposed schema) before opening the workspace. This makes configuration exclusion part of actual device acceptance, instead of inferring it from SQL metadata. No token/identity is accepted from URL parameters or arbitrary origins.

## Checks

- `node --test scripts/planner-live-api.test.mjs`: six mock-transport groups, including identity mismatch, safe RPC arguments, bounded refresh, private-schema exclusion, ambiguous write confirmation and stale response after signout.
- `node scripts/planner-live-smoke.cjs`: desktop/mobile browser contexts sharing an explicit mocked transport; creation, visibility, per-person/once completion, sibling restrictions, stale version, literal rendering, signout failure, no storage/overflow/page errors. This is NOT real Auth or network evidence.
- Existing59 local PostgreSQL and hosted SQL-role checks remain separate evidence for database rules.

## Live acceptance (pending until observed)

1. Open the current dedicated preview URL from the newest log entry. Sign in as A on Mac using its saved password. Successful workspace entry includes actual Auth/user/membership/list/private-schema checks.
2. Open the same URL on phone and sign in as B. On A, add `Fictional v134 picnic preparation`, Individual, assigned to B. B refreshes, sees it and marks complete. A refreshes and sees attributed completion.
3. On B, add `Fictional v134 drawing activity` under Activities. A and C see it; C has no Rename/complete controls. B's Tasks view has no creation form.
4. With A, create a Household item eligible for B/C and a Shared item assigned B/C. B completion finishes Household once. Shared stays partial after B and finishes only after C. Confirm no repeat contribution and distinct actors.
5. Sign out on a device and confirm planner data disappears. Never send passwords or authentication tokens as evidence. Capture independent provider final records and role/policy state; preserve test rows pending separately approved cleanup.

Leaked-password protection remains disabled because the provider organization is Free and the user chose to keep it Free. Current provider docs require Pro or higher. This is an optional security recommendation, not a technical prerequisite for household use or a required paid upgrade. No paid upgrade or Auth setting change performed.

Real credentials are saved on the user's devices, not available to the worker. The worker also has a restricted HTTP destination policy. Deploying code and passing mock/SQL tests do not substitute for actual device acceptance. Do not reset passwords, mint JWTs or bypass network policy to manufacture a PASS. Do not promote to production or merge based on this preview.
