# Connected household features — release-readiness review

Current tested preview: v154, https://steven-os-mobile-test-78a4syx9h-burns6.vercel.app/

## Result

The implemented connected household scope passes the current automated release checks. This is a tested development preview, not a production promotion or a declaration that every original private section has been made shared.

| Evidence | Result | Coverage |
| --- | --- | --- |
| Ten current request/model test files | PASS | Session concurrency, verified identity, permissions/scope validation, username handler, planner rules, Eastern calendar dates, Finance calendar projection, recovery, private/shared exports |
| Eight mocked browser flows | PASS | Shared family shell, original private source, planner panel, calendar UI, groceries, Finance workbench, Finance summary, password recovery |
| Six hosted rollback SQL-role suites | PASS | Finance access/workflow, private original access/version saves, routine controls/generation, shared calendar, shared groceries |
| Original source compatibility | PASS within exercised flows | Eleven original tabs, five calendar views, shared bridges, mobile fit, snapshots, private HTML/JSON recovery and separate shared download |
| Preview hosting | READY | Existing v154 deployment retained; no new runtime changes in this review |
| Family live acceptance | User confirmed earlier | Shared planner/calendar; v152 shared grocery cross-device pickup and correct attribution |

Hosted tests simulate database request identity/roles, not actual user JWT sign-ins. Browser tests use mocked provider/data transport and private local original inputs, not family passwords. Deterministic session tests cover expiry races; they do not demonstrate that a physical browser remained signed in for a full real token lifetime. A direct unauthenticated REST probe from the execution environment could not reach the provider, so it is NOT treated as live API evidence. Hosted role/ACL denial tests passed independently.

## Reliability work completed during review

Older access tests were adjusted to support legitimate evolving data: confirmed financial revisions are allowed while provenance remains required; private workspace tests force a unique rollback-only change and scope denial checks to the tested source; routine generation expectations use the current enabled template count. The recovery browser harness now checks the existing pinned recovery link rather than trying to submit the intentionally hidden legacy form. These are test corrections; no runtime behavior, Auth settings or financial values changed in this review.

All hosted test edits were rolled back. A post-check found zero retained workspace test markers and zero generated Finance test households. The historical root index hash remains unchanged. No family data cleanup was performed.

## Security status

The existing optional [leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) warning remains under the selected Free plan. The known [private scheduler table RLS INFO](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) remains intentional. No new advisor finding appeared. These are existing conditions, not new prerequisites imposed by this review.

## What is complete and what needs the family

Implemented: shared Tasks/Activities, role-based completion/assignments, routines, calendar audiences, groceries, manual parent Finance review/calculation/approval, original layout integrations, clearer shared mobile navigation, private recovery files and a separate scoped shared-data export.

Still needs actual information or a decision:

1. Parents confirm current Finance balances, bill sources and a cash snapshot through the workbench. A developer cannot truthfully certify dated amounts as current.
2. Choose which private original collection becomes shared next: Goals, Priority Board or Businesses, and then agree its visibility/edit rules. Existing records stay private until explicitly selected.
3. Resume collaborator onboarding together when ready. The code is on the active draft implementation branch, not merged main.
4. A reviewed production release/merge, transaction/bank integrations and automatic shared-data restoration remain separate work. No paid plan or money movement is enabled by this readiness review.

Use CURRENT_STATUS.md for the active branch/preview. The generic numbered update series continues separately from the unchanged historical log. Do not repeat accepted family tests simply to re-prove the same completed grocery flow.
