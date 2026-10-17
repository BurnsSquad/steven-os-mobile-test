# Sandbox setup proposal — approval pending

Prepared 2026-10-16. Target ONLY: Burns Base Security Sandbox, project reference `wozynsftofkjqwlflosv`. Do not execute until the user explicitly approves this step. This proposal is newly authored test infrastructure, not a recovered production migration.

## Observed preflight and limits

Public-table inventory returned zero rows (screenshot). Auth user count is zero (user report). SQL Editor execution/connection roles are postgres; PostgreSQL 17.11 (screenshot). Default grants retain privileges we do not want ordinary clients to have, so each new table explicitly revokes all grants from anon/authenticated/PUBLIC. These observations do not prove runtime access, ordinary-user RLS enforcement, or the original project's identity. Do not import production schema/data or repoint any existing Steven OS browser configuration.

## Whole test sequence and required permissions

1. Proposed next operation: create three EMPTY test tables only, enable RLS and withhold ordinary client access. Requires sandbox SQL Editor postgres schema-creation/ownership privileges. No credentials need to be shared.
2. Later, separately guided setup: create three fictional Auth identities through supported Supabase Auth administration, with passwords stored in protected secrets. A/B will belong to a fictional household; C will remain unrelated. A separate fixture in another fictional household is needed for meaningful negative UPDATE tests. Creation of identities/memberships/fixtures is not included in this approval.
3. Review/apply sandbox-only exact policies and least privileges matching the intended private/shared architecture, then verify effective table AND column privileges and RLS. Membership writes remain admin-only; private tasks remain owner-only. Shared UPDATE permits only title/completed; shared DELETE initially remains denied.
4. First authenticated behavior: A/B disposable UPDATE with independent read-back, immutable-field protection, existing unrelated-row denial and protected baseline checks. Next verify DELETE denial with specific authorization errors and existing-row evidence. Do not execute the broad household PATCH in the existing v131 page; it cannot supply sufficient isolation proof. Test code must be reviewed before running.
5. Test C isolation across membership/shared SELECT/INSERT/UPDATE/DELETE; distinguish privilege denial from row filtering. Separate temporary private fixtures may be used for private-policy regression checks. SQL Editor admin results cannot substitute for ordinary authenticated enforcement tests.
6. Only if separately requested/approved: choose member-wide versus creator-only shared DELETE semantics, review exact policy/grant SQL and reversal, then test allowed and denied deletion. No default DELETE enabling is implied.
7. Review an exact disposable-fixture cleanup manifest and SQL; obtain destructive-operation approval. Verify all baseline IDs, policies, memberships, privileges and row counts afterward. Retain evidence with credentials removed. No production access, policy changes, membership changes or personal records involved.

Expected results are assertions, not existing PASS claims. Authentication failures, missing targets, network errors or wrong error reasons are INCONCLUSIVE.

## Proposed first mutation: exact SQL

Check the dashboard project reference above before pasting. This transaction creates only the three named tables; it does not create users, policies, memberships or rows, and changes no project-wide default privileges. Do not run partial selections. If any check fails, stop and report the error rather than repairing or rerunning blindly.

```sql
BEGIN;

DO $guard$
BEGIN
  IF current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Unexpected execution role; stop';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_tables WHERE schemaname = 'public'
  ) THEN
    RAISE EXCEPTION 'Public tables already exist; stop and inspect';
  END IF;
  IF EXISTS (SELECT 1 FROM auth.users) THEN
    RAISE EXCEPTION 'Auth users already exist; stop and inspect';
  END IF;
END
$guard$;

CREATE TABLE public.bb_test_private_tasks (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES auth.users(id),
  title text NOT NULL,
  completed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.bb_test_household_members (
  household_id uuid NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  role text NOT NULL CHECK (role IN ('owner', 'member')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (household_id, user_id)
);

CREATE TABLE public.bb_test_shared_tasks (
  id uuid PRIMARY KEY,
  household_id uuid NOT NULL,
  created_by uuid NOT NULL REFERENCES auth.users(id),
  title text NOT NULL,
  completed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.bb_test_private_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_test_household_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bb_test_shared_tasks ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE
  public.bb_test_private_tasks,
  public.bb_test_household_members,
  public.bb_test_shared_tasks
FROM PUBLIC, anon, authenticated;

DO $verify$
DECLARE
  actor text;
  table_name text;
  operation text;
BEGIN
  FOREACH actor IN ARRAY ARRAY['anon', 'authenticated'] LOOP
    FOREACH table_name IN ARRAY ARRAY[
      'bb_test_private_tasks',
      'bb_test_household_members',
      'bb_test_shared_tasks'
    ] LOOP
      FOREACH operation IN ARRAY ARRAY[
        'SELECT', 'INSERT', 'UPDATE', 'DELETE',
        'TRUNCATE', 'REFERENCES', 'TRIGGER', 'MAINTAIN'
      ] LOOP
        IF has_table_privilege(
          actor, format('public.%I', table_name), operation
        ) THEN
          RAISE EXCEPTION 'Unexpected effective grant: % % %',
            actor, table_name, operation;
        END IF;
      END LOOP;
      IF has_any_column_privilege(
        actor, format('public.%I', table_name),
        'SELECT,INSERT,UPDATE,REFERENCES'
      ) THEN
        RAISE EXCEPTION 'Unexpected column privilege: % %',
          actor, table_name;
      END IF;
    END LOOP;
  END LOOP;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_tables
    WHERE schemaname = 'public'
      AND tablename IN (
        'bb_test_private_tasks',
        'bb_test_household_members',
        'bb_test_shared_tasks'
      )
      AND NOT rowsecurity
  ) THEN
    RAISE EXCEPTION 'RLS is not enabled; stop';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'bb_test_private_tasks',
        'bb_test_household_members',
        'bb_test_shared_tasks'
      )
  ) THEN
    RAISE EXCEPTION 'Unexpected policy; stop and inspect';
  END IF;
END
$verify$;

COMMIT;
```

## Expected outcome, verification and rollback

The transaction should commit with three new empty tables, RLS true on each, zero policies, and no effective table/column privileges for anon/authenticated. There should still be zero Auth users. No rows are inserted. Existing service/admin defaults are not revoked; ordinary-user tests will never use service-role credentials. RLS does not stop a privileged owner/admin from accessing tables, so this is an ordinary-client boundary, not a claim that administrators cannot access them.

The guard prevents reuse after setup and stops on unexpected public tables/users. This is intentionally not an idempotent script: do not add IF NOT EXISTS to bypass drift. SQL has been reviewed as a proposal but NOT executed or validated against a live/local PostgreSQL instance. The next guided step after approved execution will independently query table counts, identities, policies, RLS flags and effective grants. A success message alone will not close verification.

Before COMMIT, a transaction failure prevents these changes from committing; if a transaction remains aborted/open, run ROLLBACK only, then investigate in a separate read-only query. Do not assume editor session persistence or blindly run COMMIT after an error. Inspect actual state before retrying.

After a successful COMMIT, ROLLBACK cannot undo the setup. If removal is needed, first snapshot definitions/grants and prove all three tables remain empty, have no new dependents, and are the newly created sandbox objects. Prepare exact DROP TABLE statements with RESTRICT, obtain separate destructive-operation approval, and remove only those tables. Never CASCADE, drop schemas, delete Auth users or delete/recreate a project as automatic recovery. No cleanup is needed immediately because this step creates no fixture records; later fixture cleanup has its own exact manifest and approval.

## Beginner explanation

A table stores one kind of record. UUID columns identify records/accounts/households. A foreign key requires an owner/creator to be a real Auth user; household membership remains a separate authorization rule. A transaction groups changes so a failed setup can be rolled back before commit. Grants decide whether a database role can perform an operation; RLS decides which rows ordinary users can reach after a grant exists. With no client grants and no policies, these new tables start closed while we prepare reviewed test-only access.
