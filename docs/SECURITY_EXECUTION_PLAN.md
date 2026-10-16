# Household security execution plan

Status: REVIEW PREPARATION ONLY. No live database test has run in this session.
The user's current safeguards govern execution. The attached handoff supplies project history, not blanket permission. Preserve the offline single-file architecture; tests and documentation remain separate. Do not deploy, merge, synchronize browser storage, or touch personal records.

## 1. Establish the environment before writes

Confirm the exact isolated Supabase project reference/URL through protected configuration, its purpose, network access, and ordinary authenticated fictional test identities A/B/C. A and B need approved test-household memberships; C must have none. Do not reuse personal sign-in credentials or create users/memberships in the existing project without approval. Do not request secrets in chat. Environment status currently reports no secret bindings, runtime variables, or outbound identities. A public repository or publishable key does not establish database authorization.

Obtain a timestamped, read-only admin snapshot of RLS flags, policies, table AND column privileges, exact fictional fixture identities, and relevant counts. Inspect only the named test tables and fictional rows; do not export auth.users or personal data. Record A/B/C pseudonyms and protected evidence references, never passwords or tokens. SQL Editor is elevated: use it for metadata and existence evidence, never as proof of user RLS.

Read-only metadata queries (administrator runs in the confirmed environment):

```sql
BEGIN READ ONLY;
SELECT c.relname, c.relrowsecurity, c.relforcerowsecurity
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN
 ('bb_test_private_tasks','bb_test_household_members','bb_test_shared_tasks');
SELECT tablename, policyname, roles, cmd, qual, with_check FROM pg_policies
WHERE schemaname='public' AND tablename IN
 ('bb_test_private_tasks','bb_test_household_members','bb_test_shared_tasks')
ORDER BY tablename, policyname;
SELECT grantee, table_name, privilege_type FROM information_schema.table_privileges
WHERE table_schema='public' AND table_name IN
 ('bb_test_private_tasks','bb_test_household_members','bb_test_shared_tasks')
ORDER BY table_name, grantee, privilege_type;
SELECT grantee, table_name, column_name, privilege_type
FROM information_schema.column_privileges
WHERE table_schema='public' AND table_name IN
 ('bb_test_private_tasks','bb_test_household_members','bb_test_shared_tasks')
ORDER BY table_name, grantee, column_name, privilege_type;
COMMIT;
```

Also inspect effective privileges with `has_table_privilege` and `has_column_privilege` for anon/authenticated, including inherited grants; catalog grant rows alone do not prove effective access. Expected shared-task UPDATE: table false; title/completed true; created_by/household_id false. Expected DELETE false. Verify membership writes unavailable and private policies unchanged. Snapshot narrowly identified baseline rows separately without exposing personal record contents.

## 2. v131 UPDATE first

Review `Steven_OS_v131_Shared_Task_Update_Security_Test.html:1610` before running. Its fixed household is bba20000-0000-4000-8000-000000000001; baseline bba30000-0000-4000-8000-000000000001 must remain untouched. Disposable UPDATE fixture IDs are bba60000-0000-4000-8000-000000000001 and ...0002. Titles are `TEST ONLY - Steven fictional shared UPDATE check` and `TEST ONLY - Amanda fictional shared UPDATE check`; successful runs temporarily append ` - edited` and set completed true, then restore title/completed false. Fixtures are retained, not deleted. Do not repoint the existing page at fictional accounts: it hardcodes the two existing approved email identities. A future isolated runner must use protected test identity configuration.

After approved fixture setup and admin existence evidence, run A and B separately with fresh ordinary sessions: update title/completed, require exactly one returned row and independent read-back; verify all immutable fields including id, created_by, household_id, created_at. Attempt creator/household updates on the disposable row only; require specific permission error (e.g. PostgreSQL 42501), valid authentication before/after, and unchanged admin snapshot. HTTP 401, network errors, malformed payloads, or foreign-key errors are INCONCLUSIVE, never PASS.

Replace v131's broad other-household PATCH in the future runner with an exact preverified disposable row ID AND household filter. Require a real fixture in an unrelated household, zero affected rows for the unauthorized actor, and independent unchanged-row evidence afterward. An empty query against an absent row proves nothing. Test peer editing only after explicitly approving that behavior on a disposable fixture. Stop at any failure; do not automatically retry writes.

## 3. DELETE permissions

First verify existing deny behavior: absent effective authenticated DELETE grant and no applicable DELETE policy, then attempt deletion of an approved existing disposable row with ordinary authentication ONLY after destructive-test approval. Require the intended authorization error and unchanged row evidence. Do not infer policy behavior from privilege denial: a missing grant prevents reaching RLS.

Enabling DELETE is a separate production-permission decision. Ask whether any household member or only the creator may delete. Prepare exact SQL, affected roles, table/column grant and policy diff, and reversal SQL for review AFTER that decision and current policy snapshot. No speculative policy is included or applied here. A branch or PR approval is not database-change approval. If permission changes are approved, rerun negative checks and authorized deletion on disposable rows only.

## 4. Unrelated third fictional account

C has no membership. Confirm identity and absent membership through protected setup/admin evidence. SELECT membership must return []; filtered and unfiltered shared SELECT must reveal no unauthorized rows. INSERT must fail specifically authorization checks. UPDATE and DELETE must target verified existing disposable rows in A/B's household and leave them unchanged. Record separately whether denial comes from grants or RLS. Authenticate C normally, never with service_role or SQL Editor impersonation as the sole evidence. Recheck private-table isolation using fictional fixtures without modifying private policies or memberships.

## 5. Controlled cleanup and rollback

Before any deletion, prepare a manifest per disposable row: exact UUID, household UUID, creator UUID, exact current title/completed and created_at, run identifier, expected count, and prior snapshot. Exclude all protected private/shared baseline IDs. Preview exact SQL and obtain approval. The reviewed transaction should lock/select those exact rows, assert identity and expected count, delete with all identity predicates and RETURNING, assert returned rows/count, then commit only the expected set. Any mismatch requires ROLLBACK and investigation. Never TRUNCATE, delete by prefix alone, or broadly delete a household. This plan intentionally contains no executable cleanup mutation while state/approval are unknown.

An uncommitted transaction can roll back deletes. After commit, recovery requires an approved exact fictional-row restoration from the snapshot; it is not an automatic rollback. Account deletion and membership cleanup are separate approvals and are outside the existing-membership safeguard. Do not remove existing members.

v131 catches errors without guaranteed fixture restoration. If interrupted after PATCH, inspect the exact fixture; do not rerun blindly. Review a conditional restoration of only title/completed against its full verified identity. If protected fields or baseline changed, halt and preserve evidence; no automatic repair of unknown data. Local documentation rollback: revert only this branch's documentation/scripts commit, never reset index.html or browser storage. Permission rollback must restore the captured original grants/policies exactly, not generic revoke/drop guesses.

## 6. Final verification and evidence

Repeat metadata, private/shared baselines, exact counts/identities, membership snapshot, and all approved client checks after cleanup. Compare policies/grants before/after; explain every approved difference. Run `node scripts/audit-html.mjs`, `git diff --check`, and inspect changed paths. Stable SHA-256 must remain aecb177cdebe6eded90f5e5b9626e152fd677066b923e8b988ece2b83c6683f8. Desktop/mobile smoke tests must use fresh browser profiles without personal storage; record actual viewport, page actions and console errors. Syntax checking is not browser testing.

For every case record UTC and America/New_York timestamp, project reference, git SHA, actor pseudonym, fixture ID, precondition existence evidence, request method/path/payload without headers, expected status/SQLSTATE and rows, actual status/SQLSTATE and rows, read-back, baseline checks and artifact reference. Redact credentials and personal data before saving. Mark PASS/FAIL/BLOCKED/INCONCLUSIVE explicitly. Token expiry, concurrent changes and cleanup failures need their own outcomes.

## Teaching notes and future automation

A grant is permission to use a database operation; RLS decides which rows that operation may reach. SELECT USING filters readable rows; INSERT WITH CHECK validates new rows; UPDATE USING selects editable old rows and WITH CHECK validates the resulting row. Column grants limit which fields can change even within an allowed row. Membership is the shared-access boundary; private rows remain owner scoped. Missing rows can mimic successful isolation, so independent existence evidence matters.

A reusable live runner remains pending protected configuration and explicit automation approval from the handoff. It should validate project allowlist, disposable manifest, identity/membership and clean baseline before writes; use ordinary authenticated sessions; default to read-only; require approved mutation/cleanup gates; redact output; stop on unexpected state; and never silently create accounts or change policies. No GitHub Actions workflow, service-role access, or live mock-based PASS claim has been added. The included offline parser is reusable preparation, not a Supabase test runner.
