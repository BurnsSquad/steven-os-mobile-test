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
