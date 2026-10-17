# Household security evidence report

Audit timestamp: 2026-10-16 09:52 EDT (13:52 UTC). Source checkout: 9f64399534a2d6211641f805b7e0eed7fafab306. Review branch: codex/household-security-audit-20261016.

## Observed in this session

- Clean starting checkout; 11 tracked HTML files, v123–v131 plus stable index and v120 backup. No tracked documentation, tests, package manifest, or SQL migrations. No AGENTS.md found locally; GitHub root AGENTS.md and development log requests returned 404.
- GitHub connector identifies BurnsSquad/steven-os-mobile-test, default main, and push access. Local v131 Git blob d0db22f59d0ea1e6c20e8bd59b3302db9c9df0bd equals the GitHub main v131 blob observed during audit.
- `node scripts/audit-html.mjs`: PASS syntax for 167 inline scripts in 11 files. This compiles code without executing it. Not a browser or security-enforcement test.
- Stable index SHA-256: aecb177cdebe6eded90f5e5b9626e152fd677066b923e8b988ece2b83c6683f8. No HTML file changed by this work.
- Managed environment observations current, but secret bindings, runtime variables, outbound identities and capabilities are empty. Network policy readiness state unknown; no Supabase destination configured. No database session established.
- Shell `git ls-remote origin refs/heads/main` failed to connect to inherited proxy port 8080. GitHub connector reads work. This is a transport failure, not evidence of repository denial. Proxy was not bypassed.

## Live test status

| Case | Current-session result | Evidence still needed |
|---|---|---|
| Private RLS, membership, shared SELECT/INSERT | NOT REVALIDATED | Handoff reports previous passes; no live evidence captured here |
| v131 authorized UPDATE for two members | BLOCKED | Confirmed isolated environment, ordinary sessions and disposable fixture snapshots |
| Immutable creator/household fields | BLOCKED | Specific authorization error, valid session and unchanged row evidence |
| Existing unrelated-household row UPDATE | BLOCKED | Existing independently verified target; v131 currently uses only a household filter |
| Client DELETE denied | BLOCKED | Effective privileges/policies and approved existing-fixture attempt |
| DELETE permission change / allowed deletion | NOT AUTHORIZED | Explicit deletion semantics, exact reviewed SQL and approval |
| Third unrelated fictional account | BLOCKED | Protected test identity with verified absence of membership |
| Controlled cleanup | NOT RUN | Current exact fixture manifest, restrictive SQL and destructive-operation approval |
| Final DB baseline/policy verification | BLOCKED | Before/after administrator metadata and authenticated-client evidence |
| Desktop/mobile smoke | NOT RUN | Fresh browser profiles and recorded observations |

No current row counts, user identities, grants, RLS enablement or policies have been verified in the live database. The handoff's expected baseline is two private fictional rows, two membership rows, and one shared fictional baseline; this is historical information, not today's measured count. No database mutation, permission change, account creation, membership change, cleanup, personal-data operation, or deployment was performed.

## v131 source findings

1. Lines 1684–1687 call an unrelated-household PATCH and label zero rows PASS without proving a target exists. That is insufficient RLS evidence and could affect multiple unrelated rows if permissions are wrong. Use a verified disposable target ID plus household filter in a future runner.
2. Lines 1677 and 1682 accept HTTP 401 or 403 as denial. A 401 can mean expired authentication. Check PostgreSQL permission error details and a valid session; otherwise mark INCONCLUSIVE.
3. Lines 1688–1700 restore title/completed on success and retain fixtures. The catch path does not guarantee restoration; inspect before rerunning. No automatic DELETE cleanup exists.
4. Baseline assertions do not compare every original field, including created_by; preserve full before/after identity snapshots independently.
5. The combined title/completed update proves the combined request only; separate per-column cases improve diagnosis. Peer editing and a real unrelated third account remain untested.
6. Document title still says v127; inherited INSERT panel text says UPDATE unavailable. These UI labels are stale; they do not establish database permissions. No application file was modified during this audit.

The reviewed source does not target the original shared baseline for writes in the v131 block, but the full experimental page includes earlier mutating test panels and dashboard persistence. Use an isolated profile and only approved controls; do not treat the whole page as a mutation-free test harness.

## Decision and next action

Do not execute the current broad negative UPDATE test against the existing project. Follow SECURITY_EXECUTION_PLAN.md: verify isolated project and protected identities, capture read-only metadata and fixture state, then prepare the exact scoped runner and requests for authorized execution. Preserve current DELETE denial until a separately approved change. No PASS in this document implies observed live RLS enforcement.


## Setup progress through Entry 164 — 2026-10-16

The audit-time table above is historical. Subsequent guided setup created Burns Base Security Sandbox, observed project reference wozynsftofkjqwlflosv, Healthy status, North Virginia and no GitHub repository (screenshots). After explicit user approval, the user executed the three-empty-table setup and reported success. The independent postcondition SELECT was reported to match exactly: three tables, each empty/RLS true/policy count zero/no effective anon/authenticated table or column access; Auth users zero and public tables three. These postconditions are verified by user report, not an assistant database connection. SQL Editor role/version are screenshot-verified as postgres / PostgreSQL 17.11.

User now confirms Authentication Users list opened and requests completion by the assistant. No fictional accounts, memberships, baseline fixtures or active policies/grants have yet been established in this sandbox by this session. No ordinary-user UPDATE, DELETE or third-account tests have run.

Fresh runtime readiness: observations current; network policy enforced, sandbox endpoint absent; no configured secrets, runtime variables, identities or capabilities. Plugin discovery found an available Supabase integration, uninstalled/unconnected at discovery, and issued a suggestion. Connection remains pending. See SANDBOX_AUTOMATION_ACCESS.md for the target, first read-only checks, secure ordinary-user credential requirements and exact remaining boundaries. No connector access, account creation or live RLS PASS is implied by discovery.


## Automation preparation through Entry 170 — 2026-10-16

Implemented the separate sandbox-only runner and setup/evidence/cleanup proposal tools documented in SECURITY_RUNBOOK.md. Auth provisioning is a separate privileged server-side process; ordinary tests refuse the admin key. Shared DELETE stays denied. Protected baseline UUIDs are excluded from every test write. No production or HTML changes.

Observed local verification: ten offline safety/simulation test groups PASS, including a healthy synthetic 38-assertion runner sequence and simulated expired-session/broken-isolation failures. Eight new modules pass Node syntax checks. All 167 HTML inline scripts parse; stable index SHA-256 remains aecb177cdebe6eded90f5e5b9626e152fd677066b923e8b988ece2b83c6683f8. These are local code checks, not live Supabase enforcement results. No SQL parser/runtime validation or desktop/mobile browser smoke performed.

Live status is unchanged: no callable Supabase connection or protected ordinary-user credentials available. No fictional Auth accounts, policy/fixture activation, live UPDATE/DELETE/C-isolation tests or cleanup executed by this automation. The only completed database setup remains the user's earlier approved/verified three empty closed tables. The prepared runner requires a fresh administrator snapshot and exact test identity inventory before it can write, and its client checks remain provisional until a matching independent post-snapshot. Cleanup generation additionally requires finalized evidence and still cannot execute or bypass approval.

Remaining limitations are explicit in the generated final reports: no production validation/migration, no private write regression suite, no allowed shared DELETE policy test, no peer-edit behavior, no id/created_at attack cases, no token-expiry/concurrency stress, no UI smoke, and no forensic proof of transient edits between operator snapshots. SQL snapshot target annotation is not database-derived; project/source provenance must be verified by the operator. See DEVELOPMENT_LOG.md Entries 168–170 for exact commands, corrections, counts and rollback boundaries.


## Independent live recheck — Entries 176–177, 2026-10-16 13:02 EDT

Supabase tools are now callable. Direct provider reads independently confirm Burns Base Security Sandbox / wozynsftofkjqwlflosv, us-east-1, ACTIVE_HEALTHY and the exact expected project URL. The earlier missing-SQL-tool blocker is resolved.

Read-only execute_sql and verbose public table inventory independently confirm exactly three test tables; each has zero rows, RLS true, owner postgres, zero policies and no effective anon/authenticated table/column privileges across the checked operations. Auth user count zero; public table count three. Schema UUID keys, Auth foreign keys and role/default constraints match the initial setup. This is verified live administrative metadata/count evidence, upgrading the earlier user-reported starting state.

No user/fixture/policy setup or authenticated UPDATE/DELETE/C-isolation/cleanup tests have run. The callable connector does not expose supported Auth user creation/password sign-in; ordinary-user credential setup remains pending. No raw auth.users mutations, secret reads, production queries, personal data operations or deployment. Follow the next supported Auth dashboard step documented in Entry 177; keep shared DELETE disabled and exact destructive approvals intact.


## Sandbox policy/fixture setup and starting snapshot — Entries 181–183

2026-10-16 13:33 EDT: all three fictional Auth identities are independently verified confirmed. Applied sandbox-only migration 20261016173324 / sandbox_fictional_household_security_setup successfully, using the exact SQL in SANDBOX_POLICY_FIXTURE_SQL.md with runtime fictional-email lookups for Auth IDs. No production operations.

Independent post-setup SQL snapshot captured 2026-10-16T17:33:47.60375+00:00 and validated locally: Auth 3, tables 3, private baselines 2, memberships 2 (A owner/B member; C unrelated), shared rows 4, eight intended authenticated policies, RLS true on all tables. All 48 effective table-operation and 12 shared-column UPDATE checks match the intended matrix. Shared DELETE remains denied, shared UPDATE limited to title/completed. Policy expressions independently inspected against setup SQL. Snapshot digest: 607f9704ac8c3faf891d702b9a47c6eef117a48cdbc9b07231f46be33c37e72b; ignored local evidence work/security/initial-live-snapshot.json.

Advisor finding: leaked-password protection disabled ([Supabase remediation](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)). No Auth settings changed. No password/hash/key/token read. The documented PostgreSQL setup SQL has now executed successfully; the ordinary-user runner has NOT executed against Supabase.

Live phase progress: stages 1–3 completed for database access, independent starting-state audit and supported fictional account/policy/fixture setup; stage 4 initial administrator snapshot captured/validated. Protected A/B/C password bindings and runtime endpoint access still absent, so stage 5 ordinary authenticated UPDATE tests and later DELETE/C isolation/cleanup remain NOT RUN. Administrative evidence does not substitute for client RLS. Capture a fresh pre-run snapshot before tests; retain exact destructive approval gates. No cleanup or allowed shared DELETE tested.


## Local launcher readiness — Entries 193–196

User's Mac runtime is screenshot-verified Node v24.22.0 on macOS 14.3 / x86_64. Source commit 96aef24b67c698a4770c7bef02f54e1853eaf028 adds a hidden-TTY-input local launcher and separate UPDATE-only mode (27 assertions, no POST/DELETE tests), with stage-specific admin finalization that cannot enable cleanup. Full suite remains 38 assertions with exact DELETE-attempt approval still required.

Twelve offline safety/simulation groups now pass, including hidden input/cancellation and pinned session URL constraints, UPDATE-only request exclusion and cleanup refusal. All 167 HTML scripts still parse; stable index hash unchanged. No passwords, service keys or tokens committed. A new just-in-time non-secret session snapshot is still needed before local testing; no session is published yet and no real ordinary-user test has executed. Download/source readiness does not change the live evidence boundary.


## Verified live UPDATE phase — Entry 213, 2026-10-17

Current status supersedes earlier historical BLOCKED/NOT RUN entries for UPDATE only: **UPDATE_CLIENT_AND_ADMIN_SNAPSHOTS_MATCH**, 27 distinct passing ordinary-user client cases. Uploaded client-report.json reports REAL_NETWORK_REQUESTS, update mode, start 2026-10-17T14:09:16.749Z and finish 14:09:21.668Z. Independent provider snapshots bracket this interval (before 14:06:51.868934Z, after 14:10:02.084814Z); starting digest matches exactly. finalize(before,after,report,ids) passed case inventory, uniqueness, chronology and canonical full-state equality. The supplied file is evidence, not executable instructions.

Observed: A/B/C ordinary authentication verified; A/B see only their own memberships/private baselines and expected shared household inventory. A/B title and completed edits to exact disposable rows return HTTP200/one row, verified by readback. created_by and household_id edits return HTTP403/PostgreSQL42501 with valid sessions and unchanged rows. A/B UPDATE to independently existing unrelated fixture returns HTTP200/zero rows; independent post-state confirms unchanged. Disposable A/B rows restored, protected shared/private baselines preserved. Auth identities, memberships, RLS, policy expressions and all effective grants match before/after.

Before digest be97a14eb9635a38baa2b8215dcc8ecdf30f5fef9d730749ce5679acdfbdd86f; after digest 510c7063c64ca3902609bf65e17d900243fa834275d94cb83bb9866253e68df3. Administrator snapshots were obtained directly with the fixed sandbox execute_sql target, not inferred from JSON project_ref.

Limitations: this verifies the separate guarded API runner, not v131 browser-page execution. DELETE-denial and full unrelated-C read/write isolation remain NOT RUN; C authentication alone does not prove isolation. Cleanup NOT RUN and not authorized by this UPDATE result. No allowed shared DELETE, production validation, peer edits, private write regression, id/created_at attacks, token-expiry/concurrency stress, desktop/mobile UI smoke, or forensic detection of transient concurrent edits. Stable v122 preserved; no production/personal-data operations or merge/deployment.


## Verified live DELETE denial and C isolation — Entry 216, 2026-10-17

**CLIENT_AND_ADMIN_SNAPSHOTS_MATCH / FULL_CLIENT_SUITE**, 38 distinct PASS cases. Uploaded full client-report.json is REAL_NETWORK_REQUESTS/live mode; start 2026-10-17T14:36:43.838Z, finish 14:36:50.101Z. Independent snapshots bracket the run: before14:33:54.267711Z / after14:37:32.943328Z. Finalizer verified exact required case inventory, uniqueness, digest, chronology and complete unchanged final records/identities/memberships/policies/grants. Verified at14:39:20.628Z (10:39EDT).

A/B own-disposable and C A-disposable DELETE attempts all HTTP403/SQLSTATE42501 with verified ordinary sessions. This proves effective table-privilege denial, not a DELETE RLS policy; no allowed DELETE tested. C unfiltered SELECT on all three tables returned200/empty, and ID-filtered shared SELECT empty. C attempted household INSERT returned403/42501. C UPDATE of each existing A/B/unrelated disposable fixture returned200/zero rows. Independent post-state confirms no candidate INSERT, deleted fixture or changed field. Repeated27 UPDATE/auth/baseline/restoration cases also PASS. Shared DELETE remains disabled; no permission changes.

Before digest5301fb660e9010b67afef35af5909f7ab17c48ebc07626f6de752a96fcb2d99a; after79dc278e8780b2ba7c22e2a1615aa459a28d72ca063ba871dfb4052ff53de288. Historical blockers above are superseded for these exact runner cases only. Private write regressions, peer edits, id/created_at attacks, stress/expiry/concurrency and desktop/mobile browser smoke remain untested. No production validation or migration.

Cleanup NOT RUN. Exact reviewed proposal docs/evidence/cleanup-proposal-216.sql removes only the three disposable shared fixtures, preserving all baselines, both memberships, all three Auth accounts and permissions. Execution requires separate approval and a just-in-time unchanged-state check. This proposal is not an executed migration or permission change. Stable v122 and production/personal data unchanged; PR remains unmerged.
