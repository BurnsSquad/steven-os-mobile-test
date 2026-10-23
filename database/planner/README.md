# Planner database v1 — sandbox installation and verification

This is the database implementation for the generic Tasks/Activities rules reviewed in the v133 interface. It is separate from the stable application and the older generic-member sharing tables. The schema, fictional bootstrap, hosted identity compatibility repair and foreign-key indexes are installed in Burns Base Security Sandbox. Hosted SQL-role verification passed; see tests/hosted-result.json and DEVELOPMENT_LOG.md through Entry261. Production and both preview frontends are unchanged. Do not rerun setup over the installed objects.

## Objects and permission boundary

`schema.sql` creates six new `public.bb_planner_*` tables: households, members, items, assignments, completions and append-only events. All have RLS. Authenticated household members can read shared planner data; they can read only their own membership record. Existing private tasks and old memberships are outside this model.

Browser roles have no direct writes. Five public invoker RPC functions call narrow private-schema definer functions owned by `bb_planner_executor`, a NOLOGIN/NOBYPASSRLS role with privileges on the new planner tables only. It cannot change memberships or read old private tasks. Explicit membership/role checks use verified request identity and database records, never client-selected roles or editable profile metadata. Authenticated SELECT policies use `auth.uid()`. Private executor functions use `actor_uid()`, an invoker helper mirroring the independently inspected hosted `auth.uid()` claim extraction, because managed Supabase postgres cannot grant a custom role USAGE on its auth schema. This avoids granting broader roles or adding another privileged definer. PostgREST must remain responsible for JWT verification; untrusted users must never receive direct SQL sessions able to set request claims. Private helpers are not callable by browser users. The private schema must remain outside the Supabase Data API exposed-schema list.

This is a deliberate transactional capability boundary; its executor-only policies permit the exact new-table operations needed by these functions. It does not widen existing policies or give browser roles the executor role. Keep default function access revoked. Administrator/superuser access is trusted and cannot be restricted by ordinary RLS.

## Behavior

- Adults create Tasks and Activities, rename items, and assign members of the same household before any contributions exist.
- Children create only individual Activities assigned to themselves and rename their own Activities. They cannot create Tasks, reassign siblings or change membership roles.
- Individual completion requires the assignee, or an adult acting explicitly for that assignee.
- Household completion is once for the item, with the first actor/time preserved. Eligible children can complete; an adult can complete as themselves. An adult's own assignment is recorded only if that first completion needs it.
- Shared completion records one contribution per assigned person; all required contributions produce overall completion. Adults can explicitly complete for an assignee; actor and effective assignee are stored separately.
- Item row locks serialize competing completion/assignment requests. Unique keys make repeated completion idempotent. Rename/assignment require the current `version`; stale requests fail with SQLSTATE40001 and require refresh.
- Creator, household, type and creation time are immutable through the RPC surface. Reassignment after any contribution, deletion, cancellation, reopening and scheduling remain unavailable.

Errors:42501 unauthorized;22023 invalid input;40001 stale revision;55000 contribution prevents reassignment. Do not treat unauthenticated HTTP401 as successful authorization testing.

## RPC contract

Use an ordinary authenticated Supabase client and publishable key, never an administrative key in the browser. PostgreSQL parameter names are the JSON argument names:

| RPC | Arguments |
|---|---|
| `bb_planner_create` | `h` household UUID, `i` fresh item UUID, `k` task/activity, `t` title, `m` individual/household/shared, `ids` assignee UUID array |
| `bb_planner_rename` | `i`, `t`, `v` current version |
| `bb_planner_assign` | `i`, `m`, `ids`, `v` |
| `bb_planner_complete` | `i`, optional `for_member` (adult on-behalf only) |
| `bb_planner_list` | `h` |

Mutations return the current item JSON with assignees, attributed completions and computed `complete`. List returns item JSON rows. Creation is atomic but duplicate create UUIDs return a conflict rather than silently inserting twice. Membership onboarding is administrator-only in this version; there is no public role/invite endpoint.

## Verification

Run `bash database/planner/tests/run-local.sh` with Docker and Python3. It starts a pinned PostgreSQL17.6 container with no network, no published ports and temporary RAM-backed data, then removes only that newly created disposable container. Password-free local trust is confined to that container; no hosted credentials are used. The runner mocks only `auth.users` and `auth.uid()` in a database named `bb_planner_disposable` and uses non-superuser session authorization for client tests.

`tests/local-result.json` records the actual result. Tests exercise SQL/functions/RLS, unrelated households, direct-write denial, role escalation, assignment validation, attribution, concurrent Household/Shared completion, completion racing reassignment, and guarded rollback. Local Auth stubs are not proof of Supabase JWT, PostgREST or browser integration. Hosted PostgreSQL is17.11; local17.6 is the pinned available test image.

## Exact sandbox review sequence

1. Independently confirm project `wozynsftofkjqwlflosv` (Burns Base Security Sandbox). Capture old rows, memberships, users, policies and effective grants read-only. Preserve the retained previous browser acceptance task. `verify.sql` helps inspect metadata but does not replace full before/after snapshots.
2. Obtain approval for this exact additive schema/permission setup and the separate fictional bootstrap. Ensure `bb_planner_private` is not exposed by the Data API and no executor/schema already exists.
3. For a fresh installation, in a trusted verified administrator session, set `bb_planner.approved_schema` to `planner-v1` and execute current `schema.sql`, then `indexes.sql`. The current schema includes the hosted identity compatibility fix. For the originally installed schema only, apply `hosted-identity-compatibility.sql` to update the existing private functions; do not rerun the full schema over existing objects. It is one transaction and refuses absent opt-in or an existing executor. This setting is an operator guard, not a substitute for project verification or authorization.
4. Separately set `bb_planner.approved_bootstrap` to `fictional-v1` and execute `fictional-bootstrap.sql`. It maps existing fictional A to adult and existing fictional B/C to child in **only the new planner household** `bba90000-0000-4000-8000-000000000001`. It creates no Auth users and changes no old membership. C's old unrelated-household security-test status remains unchanged in the old tables. This generic fixture mapping does not describe an actual family.
5. Recheck independent metadata and old-record snapshots, run ordinary JWT/PostgREST allow/deny tests and concurrency checks, then connect the new planner UI and test separate device sessions. Do not infer success from local tests alone. No stable-index replacement or personal-record migration.

No sample item rows are inserted by the hosted bootstrap. Ordinary-user acceptance items will need an exact later manifest and separate cleanup approval.

## Recovery

An error before `COMMIT` rolls the schema transaction back. After commit, `rollback-empty.sql` is a separate destructive proposal requiring explicit approval and `bb_planner.approved_rollback=empty-planner-v1`. It refuses if any new table contains data, uses exact object names and no CASCADE, and does not touch old tables or users. If fixtures/items exist, preserve evidence and prepare a separately approved exact cleanup/recovery plan first. This release has no automatic cleanup or destructive migration.

Production release, real onboarding, invitations and personal data remain outside this sandbox implementation. The disconnected v133 demo is unchanged until separate integration work.

## Hosted verification limits

`tests/hosted-smoke.sql` exercises the installed functions using administrator-driven authenticated-role/request-claim simulation, entirely within a transaction that is rolled back. It verifies database authorization and leaves no test items. It does not verify actual ordinary-user passwords, JWT validation, PostgREST schema exposure or browser/device flows. Direct HTTP from this worker was denied by destination policy; the proxy was not bypassed. The database has no recorded pgrst.db_schemas override; Data API exposure confirmation remains an integration check. Keep the private schema unexposed.

Provider security advisor reports the pre-existing [leaked-password-protection setting](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) disabled. No Auth setting was changed. Foreign-key index follow-up applies only to new planner tables; existing-table advisory findings are not changed by this setup.
