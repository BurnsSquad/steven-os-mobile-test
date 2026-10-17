# Direct sandbox automation access

Prepared 2026-10-16; live connection pending. This runbook supplements the dated development log; it does not establish completed testing.

## Target and boundaries

Use only Burns Base Security Sandbox, project reference `wozynsftofkjqwlflosv`, URL `https://wozynsftofkjqwlflosv.supabase.co`. Stable v122, original Burns Base database, existing production policies/memberships and personal browser records are outside scope. PR #1 must stay unmerged.

The user has now requested completion rather than continued manual navigation. Continue routine isolated setup and testing within that request; do not repeatedly ask to approve previously authorized steps. Preserve the existing gates for destructive cleanup and production permission changes. Keep shared DELETE denied unless the user explicitly chooses and approves different semantics.

## Current evidence

- Sandbox Healthy, North Virginia and no connected GitHub repository: screenshot.
- Three exact empty bb_test tables with RLS true, no policies, no effective anon/authenticated table or column permissions, zero Auth users: user report of verification query results.
- SQL Editor postgres, PostgreSQL 17.11: screenshot.
- Authentication Users list opened: user report.
- No ordinary A/B/C authenticated tests have run.
- Fresh managed-runtime observation: network policy enforced, sandbox hostname absent, no secrets/runtime variables/outbound identities/capabilities configured.
- Tool discovery found no callable Supabase or browser-control tool.
- Supabase plugin directory search found an available but uninstalled Supabase integration. A suggestion was issued; installation/connection is not confirmed. Safari login and screenshots do not give the assistant browser control or database credentials.

## One user action still needed

Install/connect the Supabase plugin through its supported authorization flow. If it offers project scope selection, choose only the sandbox reference above. If it requests broader access, disclose that scope before deciding; never treat broad connector access as permission to operate on production. Do not paste API keys, passwords, connection strings, personal backups or tokens into chat. Do not connect GitHub or Vercel from Supabase: those are deployment integrations and do not grant this chat the needed database access.

## First actions after connection

1. Inspect the newly available capabilities and their actual permissions. Directory descriptions alone do not prove Auth administration or end-user token support. Do not promise account automation until capabilities are verified.
2. Read-only identify the exact target project/reference, health and region. Rerun the closed-table verification and Auth count. Stop on unexpected identities, records, policies or privileges. Do not infer that a name matches the intended project.
3. Record evidence/time, then prepare the precise remaining isolated setup and test requests before mutation: fictional identities, policies, least grants, fixture manifest and baseline. Never read or clone production records. Do not create users through raw inserts into auth.users or craft password hashes; use supported Auth administration only.
4. Use three fictional ordinary sign-ins A/B/C with protected credentials and no invitations to real people. A/B join the fictional test household; C remains unrelated. Create an existing disposable target in an unrelated fictional household for negative checks. Protect baseline rows and freeze identity columns.
5. Run UPDATE first, with exactly scoped disposable-row requests and read-back. Require specific authorization errors plus valid sessions and independent unchanged-row checks. Never label a 401, absent target, network failure or SQL Editor owner access a successful RLS test.
6. Verify current shared DELETE denial. Then verify unrelated C isolation. A missing DELETE grant proves a grant boundary, not a DELETE RLS policy. Do not enable shared DELETE merely to make an allowed-delete case pass.
7. Preview exact cleanup identities, counts and SQL and obtain destructive-operation approval. Assert rows in a transaction and roll back on mismatch. After successful commit, recovery requires a separately reviewed exact snapshot restoration. Do not delete Auth users or memberships automatically.
8. Repeat metadata, row/count/baseline checks, stable index SHA-256 and offline syntax audit; capture new live evidence separately from local parser checks. Update log/report and PR without merging or deploying.

## Credentials and remaining technical dependencies

A database connector can provide elevated SQL but cannot by itself prove ordinary authenticated RLS. If the connected plugin cannot securely create fictional Auth users and authenticate them, inspect the protected runtime configuration workflow for exactly those remaining needs. Prefer regular test-user credentials and the public publishable key for the test runner; no service-role credential in a browser, CI output, artifact or log. Do not request a personal Supabase account token in chat.

Direct REST execution from this runtime will also need its supported network configuration to allow only the sandbox endpoint and any specifically justified database host. A network grant without credentials is insufficient; credentials without network access are insufficient. A connected plugin may provide its own authorized transport. Do not bypass the runtime proxy or silently substitute another project.

## Rollback and teaching notes

Connecting an integration changes access, not the database schema by itself. Verify the actual permissions in the authorization flow. Users can later revoke an unused connection through its supported settings; that does not undo database writes already committed. A screenshot proves visible UI state, a reported query result has an explicit evidence level, and an independently run query or authenticated request is a different level again. Preserve all three distinctions in the security report.
