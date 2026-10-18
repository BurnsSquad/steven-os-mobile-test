# Household pilot v137

Separate email/username/password pilot; previous preview URLs and the stable root index remain unchanged.

- Provider `/auth/v1/user` verifies identity. Memory-only session tokens; no browser-storage writes.
- RLS-filtered membership determines the household and role. No client role picker or embedded family identity mapping.
- Member-only directory returns IDs/roles; profiles show usernames only to members of the same household. No public email lookup. Emails remain in Auth, not profile rows.
- New `planner-identity` Edge Function supports username/password login and current-password-confirmed username changes. It uses provider-supplied server credentials exclusively inside the hosted runtime. No administrative credentials are bundled into the browser or returned to callers. Function gateway JWT check is disabled because sign-in must be unauthenticated; the handler authenticates sign-in through provider password Auth and checks the session, current password and database membership on rename.
- Profile writes are unavailable to browser roles. Service role has only SELECT, INSERT and username/timestamp UPDATE on the new profiles table; existing planner grants are unchanged. UUID/household/roles/assignments/completions remain immutable through this endpoint.
- Handles: 3–24 ASCII letters/numbers/underscores, letter first, globally unique ignoring case. Exact normalized-key lookup avoids wildcard matching. Database uniqueness handles concurrent collisions.
- Current-password confirmation also applies when selecting an initial handle through settings. Administrator bootstrap may provision initial profiles under user authorization.
- Adult email sign-in remains supported. UI labels use usernames or generic role labels; no email-as-name fallback.
- Edge has bounded request sizes, timeouts, generic login errors and best-effort isolate throttling plus provider Auth controls. The isolate throttle is not a globally coordinated rate limiter.
- Children's actual identities and profiles still require separate onboarding. Stable parent-owned email aliases can route recovery mail to the designated guardian without changing when a username changes. No aliases, recovery recipient, personal names or selected family handles are embedded in this source.
- Recovery email/callback delivery still needs live verification. Recovery request/callback flow is added below; no automatic invitation or child Auth creation is performed by the application. Finance/original records are not imported. No production promotion.

Validation: `node scripts/planner-identity.test.mjs`, `node scripts/planner-pilot-api.test.mjs`, and `node scripts/planner-pilot-smoke.cjs` use mock transport/Auth, not real credentials. Hosted SQL-role checks separately cover case-insensitive uniqueness, household visibility, no anonymous access, no direct client profile writes and immutable identity/household columns. Account owners must verify actual username sign-in and renaming.

## v137 recovery addition

The username recovery form calls the server's `recover` action. Only the Auth email already bound to the resolved profile is used; a caller cannot choose a destination, supply email content or receive the reset token. The public response does not prove account existence or email delivery. Provider failures log only a numeric status. Recovery requests have a separate best-effort per-isolate limit of three/hour plus provider controls.

`recovery.html` handles the provider's implicit recovery redirect, clears URL fragment/query before API calls, verifies the provider user and its own household/profile, and submits only a new password to Auth `/user`. Tokens stay in memory and are cleared on save/page exit. It attempts global session revocation after password update, with explicit UI notice if unconfirmed. No role, profile, membership or planner records are written by the reset page.

Before live testing, configure SMTP privately in the provider dashboard and add the deployed preview's exact `/recovery.html` URL to Auth Redirect URLs. Retain earlier redirect entries and Site URL; do not use a broad wildcard or place SMTP credentials in source. A saved SMTP form is not proof of delivery. Verify inbox arrival, intended username, password save and subsequent username login. Do not share recovery links or new passwords in chat.

Tests: `node scripts/planner-recovery-api.test.mjs` and `node scripts/planner-recovery-smoke.cjs`, plus identity/pilot regressions. All are simulated; actual SMTP/callback/reset acceptance remains separate.
