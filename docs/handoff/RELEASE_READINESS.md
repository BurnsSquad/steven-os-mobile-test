# Connected household features — release-readiness review

Current tested preview: v157, https://steven-os-mobile-test-gd6w2pcxg-burns6.vercel.app/

## Result

The implemented connected household scope passes the current automated release checks. This is a tested development preview, not a production promotion or a declaration that every original private section has been made shared.

| Evidence | Result | Coverage |
| --- | --- | --- |
| Current request/model tests | PASS | Session concurrency, verified identity, permissions/scope validation, username handler, planner rules, Eastern calendar dates, Finance calendar projection, recovery, private/shared exports and Priority request scope |
| Mocked browser flows | PASS | Shared family shell, original private source, planner panel, calendar UI, groceries, Goals, Businesses, Priority Board, Finance workbench/summary and password recovery |
| Hosted rollback SQL-role suites | PASS | Finance access/workflow, private original access/version saves, routine controls/generation, shared calendar, groceries, Businesses, Goals and priorities |
| Original source compatibility | PASS within exercised flows | Eleven original tabs, five calendar views, shared bridges, mobile fit, snapshots, private HTML/JSON recovery and separate shared download |
| Preview hosting | READY | v157 Priority Board and scoped-download preview deployed; no production promotion |
| Family live acceptance | User confirmed earlier | Shared planner/calendar; v152 shared grocery cross-device pickup and correct attribution |

Hosted tests simulate database request identity/roles, not actual user JWT sign-ins. Browser tests use mocked provider/data transport and private local original inputs, not family passwords. Deterministic session tests cover expiry races; they do not demonstrate that a physical browser remained signed in for a full real token lifetime. A direct unauthenticated REST probe from the execution environment could not reach the provider, so it is NOT treated as live API evidence. Hosted role/ACL denial tests passed independently.

## Reliability work completed during review

Older access tests were adjusted to support legitimate evolving data: confirmed financial revisions are allowed while provenance remains required; private workspace tests force a unique rollback-only change and scope denial checks to the tested source; routine generation expectations use the current enabled template count. The recovery browser harness now checks the existing pinned recovery link rather than trying to submit the intentionally hidden legacy form. These are test corrections; no runtime behavior, Auth settings or financial values changed in this review.

All hosted test edits were rolled back. A post-check found zero retained workspace test markers and zero generated Finance test households. The historical root index hash remains unchanged. No family data cleanup was performed.

## Security status

The existing optional [leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) warning remains under the selected Free plan. The known [private scheduler table RLS INFO](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) remains intentional. No new advisor finding appeared. These are existing conditions, not new prerequisites imposed by this review.

## What is complete and what needs the family

Implemented: shared Tasks/Activities, role-based completion/assignments, routines, calendar audiences, groceries, Goals/milestones, parents-only Businesses, flexible priorities with private readiness choices, manual parent Finance review/calculation/approval, original layout integrations, clearer shared mobile navigation, private recovery files, a family data download and a separate parents-only Business download.

Still needs actual information or a decision:

1. Parents confirm current Finance balances, bill sources and a cash snapshot through the workbench. A developer cannot truthfully certify dated amounts as current.
2. Businesses was selected and confirmed parents-only; v155 implements new shared business records. Goals/milestones confirmed family-visible, own management and parent management of all; implemented v156. Existing private records are not automatically migrated.
3. Resume collaborator onboarding together when ready. The code is on the active draft implementation branch, not merged main.
4. A reviewed production release/merge, transaction/bank integrations and automatic shared-data restoration remain separate work. No paid plan or money movement is enabled by this readiness review.

Use CURRENT_STATUS.md for the active branch/preview. The generic numbered update series continues separately from the unchanged historical log. Do not repeat accepted family tests simply to re-prove the same completed grocery flow.

## v155 business addition

Hosted additive parent-only tables/RPCs are installed. Rollback SQL covers parent peers, child/foreign/no-identity denials, ACLs, stale/idempotent writes, archive and attributed completion/undo; zero fixtures remain. Two new request tests and the two-parent/child mocked business flow pass. Original eleven-tab/five-calendar-view, shared-shell and recovery browser regressions also pass. Business records stay outside Finance and the shared-household export; original private records/backups remain separate. These additions do not replace the evidence limits above or constitute real-device sign-in acceptance.

## v156 goals addition

New family roadmap table/checked writes/private audit installed. Hosted rollback role tests pass child-own creation/write, sibling read-only, both-parent management, immutable ownership, 3x4 validation, stale/retry guards, completion attribution/undo, archive, ACLs and foreign/missing-identity denial. Post-check goal rows/audit fixtures zero. New mocked family goal flow and two request tests pass. Original eleven-tab/five-view source, shared-shell and recovery regressions pass; 19 targeted request/session/export tests pass. Earlier broad readiness evidence remains historical as labelled above. No fresh family-device goal acceptance or production promotion is claimed.

## Entry 312 — full-roadmap verification

Expanded hosted rollback SQL and mocked browser checks pass all 12 completions, independent parent/sibling readback, 100% progress, 92% after reopening and 100% on recompletion. Sibling controls remain read-only. Server attribution, no-op version stability and audit are checked; no fixtures retained. This completes agent-run acceptance; actual family JWT/device acceptance remains unverified. v156 runtime/deployment unchanged.

## v157 priorities and download scopes

The additive Priority tables, checked RPCs, private audit table and RLS policies are installed. Hosted rollback tests pass family read, child-own management, both-parent management, Family priorities, private per-account readiness settings, completion/reopen attribution, retry/version behavior, archive locking, ACL denial and foreign/no-identity denial. Zero rollback priority/audit fixtures remain. A dedicated three-context browser test passes personal/everyone views, recommendations, literal rendering, mobile fit and clearing; shared-shell and original-source regressions pass. The original private Priority Board remains below the connected panel and is never auto-imported.

The family export now field-limits and includes Goals/milestones and shared priorities while excluding personal readiness settings and parent Businesses. A second parents-only export field-limits Business ventures/tasks and refuses before collection reads for child accounts. Both are download-only; no restore/import claim is made.

The security advisor has the same existing leaked-password warning and private scheduler-table RLS information item. The performance advisor initially found the new completion-attribution foreign key uncovered; v157 adds the covering index, and the follow-up advisor report contains no new Priority foreign-key finding.
