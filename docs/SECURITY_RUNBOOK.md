# Burns Base sandbox security runner

This is a prepared, locally checked implementation. **No live account provisioning, policy/fixture setup, RLS tests or cleanup have been executed by it.** Current sandbox evidence remains the user's verified three empty closed tables and zero Auth users. The Supabase plugin connection is unconfirmed. Do not describe offline simulations as database enforcement results.

## Target, architecture and prerequisites

Only `https://wozynsftofkjqwlflosv.supabase.co` is allowed. All scripts are separate from the offline single-file dashboard. No HTML, localStorage, backups or personal records are read or changed. Never point the existing personal browser test page at the sandbox. This runner implements the remaining v131-equivalent cases using fictional A/B/C instead of the original personal sign-ins.

Requires Node 24 or another compatible modern Node with fetch, AbortSignal.timeout and node:test. No third-party packages. Run from repository root. No GitHub Actions workflow is enabled. The account-admin script refuses CI; the ordinary runner refuses the admin secret entirely. Do not disable these guards.

Actual network and protected configuration must be established before any live commands. A Safari login, project name or plugin suggestion does not establish executable access. With a connected Supabase tool, independently confirm the exact project reference, execution role and starting state first. If the runtime is used, configure its supported network policy for the sandbox endpoint without bypassing the proxy.

Use protected environment bindings, not chat or command-line secret arguments. Do not create an `.env` file, paste credentials into a shell command, dump the environment, or log HTTP headers/responses. `.gitignore` excludes local work/evidence and common secret files as defense in depth; it is not a secret vault. New API keys are required by these scripts; legacy JWT API keys are intentionally refused.

| Binding | Purpose |
|---|---|
| BB_TEST_URL | Exact sandbox URL above; non-secret |
| BB_TEST_PUBLISHABLE_KEY | Sandbox public key beginning sb_publishable_; runner uses it |
| BB_TEST_A_PASSWORD / BB_TEST_B_PASSWORD / BB_TEST_C_PASSWORD | Three unique fictional-user passwords, at least 24 characters, protected bindings |
| BB_TEST_A_ID / BB_TEST_B_ID / BB_TEST_C_ID | Distinct Auth UUIDs returned after supported account creation |
| BB_TEST_ADMIN_KEY | Protected sandbox sb_secret_ key, administrative creation process ONLY; not a personal account token; remove from runner process |
| BB_TEST_AUTH_APPROVAL | Sandbox reference; set only for authorized fictional-account creation |
| BB_TEST_POLICY_REVIEW | Sandbox reference; acknowledgement that actual snapshot policy expressions match reviewed generated SQL |
| BB_TEST_SNAPSHOT_ATTESTATION | Sandbox reference; acknowledgement that JSON snapshots came from the exact sandbox |
| BB_TEST_UPDATE_APPROVAL | Sandbox reference; explicit live test guard |
| BB_TEST_DELETE_DENIAL_APPROVAL | Sandbox reference; set ONLY after approval of the exact existing disposable-row DELETE-denial attempts |

The reference used by these non-secret guard bindings is `wozynsftofkjqwlflosv`. Setting a variable is an execution guard, not a substitute for user approval. Never reuse production passwords/keys. If protected bindings cannot be configured, stop before provisioning/login. The supported configuration interface depends on the host; this runbook does not invent clicks for an unavailable UI.

## 1. Offline checks — safe to run now

```sh
node scripts/security/safety.test.mjs
node scripts/audit-html.mjs
```

Ten offline test groups check exact destination/credential guards, real permission-error classification, stale/missing/drifted snapshot refusal, no redirects, no secret output on refusal, setup/cleanup boundaries, end-to-end runner simulation, and post-cleanup verification. Simulations force `OFFLINE_SIMULATION` into artifacts; the finalizer refuses to accept them as live evidence. Tests use synthetic data and a synthetic HTTP double. They prove runner behavior only.

The HTML audit compiles 167 inline scripts across 11 HTML files and checks the exact stable index SHA-256. It does not execute the app or test RLS. Browser automation packages are not installed; desktop/mobile smoke checks remain NOT RUN.

## 2. Supported Auth creation — not yet executed

Review this mutation scope before using the admin script: create exactly three new, email-confirmed fictional Auth users, no invitations/emails sent, no records or memberships added. Labels are burns-security-a@example.test, burns-security-b@example.test and burns-security-c@example.test. The `.test` domain is reserved for testing. The script uses the supported Auth Admin API, not inserts into auth.users or fabricated password hashes. Prerequisite: zero existing Auth users and explicit sandbox creation guard. Expected Auth count becomes three.

```sh
node scripts/security/provision-auth.mjs --create-fictional-users
```

It prints only actor and UUID, which must be configured as the protected runtime ID bindings. Passwords remain in protected bindings; tokens are not printed. No arbitrary email/project argument accepted. Remove the admin binding from the ordinary runner's process afterwards.

Auth administration is NOT transactional across all three API calls. On any failure, inspect exact user count/fictional IDs and keep the partial state; do not rerun blindly, auto-delete users or reset Auth. Account deletion is destructive, may interact with foreign keys, and needs exact separate approval. A small continuation operation would need to be prepared after inspecting partial state. Auth endpoint compatibility and permissions remain untested live.

## 3. Policies, grants and fixtures — generate/review before applying

With the three protected ID bindings available:

```sh
mkdir -p work/security
node scripts/security/prepare-sql.mjs setup > work/security/setup-proposal.sql
```

This command only produces SQL text and cannot connect to the database. Review it against the sandbox state before any execution. It checks the intended Auth inventory (including confirmation), empty tables, no policies, and postgres execution role; then in one transaction enables RLS, revokes ordinary default grants, creates eight policies, grants minimum operations, and inserts only the fixed fictional rows below. It changes no project-wide defaults or production policy. This is newly authored sandbox policy setup, not a verified copy of production DDL. The generated SQL has not been parsed/executed against PostgreSQL in this environment; live syntax/behavior verification is still required.

| Objects | Fixed fixtures / expected count |
|---|---|
| Private baselines | bba10000-0000-4000-8000-000000000001 and ...0002; count 2 |
| Fictional membership | household bba20000-0000-4000-8000-000000000001; A owner, B member; count 2 |
| Protected shared baseline | bba30000-0000-4000-8000-000000000001; count 1 |
| Disposable A/B UPDATE | bba60000-0000-4000-8000-000000000001 and ...0002 |
| Existing unrelated target | bba60000-0000-4000-8000-000000000099 in household bba20000-0000-4000-8000-000000000099; no A/B/C membership there |
| Total shared rows | 4 |
| Denied C INSERT attempt | bba70000-0000-4000-8000-000000000003; must remain absent |

C has no membership anywhere. The unrelated fixture is administratively created with A as creator but no A membership, testing that creator identity alone grants no shared access. No user or membership is silently created by the ordinary runner.

Expected grants: private authenticated SELECT/INSERT/UPDATE/DELETE with owner RLS; membership authenticated SELECT only on own row; shared authenticated SELECT/INSERT plus UPDATE(title,completed) only, membership-scoped. No shared DELETE grant/policy; no anon grants. Client identity columns cannot be updated in shared tasks. Existing production policies/memberships are never accessed.

If any SQL fails before COMMIT, do not salvage partial statements: ensure ROLLBACK and inspect actual state. A committed setup cannot be undone with ROLLBACK. Reverting seeded rows, policies or users after commit requires exact separately reviewed reversal and destructive approvals where applicable; never DROP CASCADE, TRUNCATE or broadly delete by household/prefix. Do not add IF NOT EXISTS or overwrite unexpected records to bypass a guard.

## 4. Capture a fresh administrator snapshot

```sh
node scripts/security/prepare-sql.mjs snapshot > work/security/snapshot-query.sql
```

After confirming sandbox reference in the dashboard/connected tool, execute only that SELECT and save the `snapshot` JSON as `work/security/before.json`. A JSON export containing one `{snapshot: ...}` row or the snapshot object itself is accepted. Do not pass CSV directly. The query includes aggregate counts and only the fixed fictional Auth labels/fixture IDs, plus RLS/owner/policy/effective table/column metadata. The snapshot is a single consistent SELECT. The JSON project_ref is a literal annotation, NOT proof of which database executed it; independently verify the project and set the attestation guard accordingly.

Review policy expressions against generated setup SQL, then set the policy-review guard. The validator checks policy names/tables/commands/roles and compares expressions before/after, but it is not a semantic SQL-policy theorem prover. A manually edited/fabricated snapshot cannot establish independent RLS evidence. Preserve source and timestamps in the permanent report.

Preflight requires the snapshot less than ten minutes old and exactly: Auth 3, public tables 3, private rows 2, memberships 2, shared rows 4, RLS true, eight policies, exact identities/values and effective privilege matrix. Unexpected extra rows/users/grants cause refusal. If the public test tables contain unexpected data, do not export unrelated row contents or erase it; investigate.

## 5. Ordinary-client preflight, then authorized tests

Run with ONLY ordinary test credentials and public key, no admin binding:

```sh
node scripts/security/run.mjs --mode preflight --before work/security/before.json --out work/security/preflight.json
```

This authenticates all three fictional users through the normal password grant and checks A/B private/shared/membership read baselines. It creates only Auth sessions; no table writes. Tokens stay in process memory and are discarded when it exits; sessions may remain until expiry and are not forcibly revoked here. Snapshot age, ID, key, policy-review and provenance guards apply. Reports never overwrite existing paths.

Before the live command, review its exact destructive-test exposure: A and B each attempt DELETE on their own disposable existing UPDATE fixture; C attempts DELETE on A's disposable fixture. Expected result is 403 / SQLSTATE 42501, because DELETE is ungranted. If permissions are wrong those rows could actually be removed, so obtain approval for these exact three attempts before setting BB_TEST_DELETE_DENIAL_APPROVAL. Preserve the full pre-snapshot for recovery. This guard is intentionally separate from UPDATE authorization. No protected private/shared baseline is ever targeted for writes.

```sh
node scripts/security/run.mjs --mode live --before work/security/before.json --out work/security/client-run.json
```

A complete live run has 38 client assertions, in order:

1. Authenticate A/B/C and verify /auth/v1/user identities.
2. A/B read their own membership/private baseline and exact shared household inventory.
3. For each of A/B: change title, read back; change completed, read back; deny created_by/household_id changes with precise authorization errors and valid sessions; attempt title update of the preverified unrelated disposable row and require zero rows; restore own fixture; verify protected shared baseline.
4. A/B DELETE-denial attempts on their existing disposable rows, with before/after read-back and valid sessions.
5. C unfiltered membership/shared/private SELECT empty; ID-filtered shared SELECT empty; INSERT into the real A/B household denied; UPDATE each of the three disposable existing targets filtered to zero; DELETE A's disposable row denied.
6. A/B final visible shared and private baselines unchanged.

All requests go only to the fixed sandbox. Own PATCHes include exact ID, household, creator, current title and completed filters. Baseline UUIDs are read only, including C negative tests. Unauthorized creator changes use a real other fictional user's UUID so a foreign-key error cannot masquerade as permission protection. HTTP 401, transport failures or incorrect SQLSTATE never count as a permission PASS.

The catch/finally path attempts restoration ONLY if the row is one of the exact known states this runner created, including all immutable fields and timestamps. Unexpected state is not overwritten. On errors, the report is STOPPED_REVIEW_REQUIRED; inspect the exact disposable fixture and evidence. No automatic INSERT repair or DELETE cleanup. Partial state may require approved exact restoration from the before snapshot; do not overwrite a protected/unknown row or automatically recreate a deleted user. Raw exceptions/API bodies are omitted to prevent accidental secret leakage; structured status/SQLSTATE/stage are retained.

Case PASS means its client assertion succeeded; the overall run remains CLIENT_CHECKS_PASSED_ADMIN_VERIFICATION_PENDING. No row-free negative case is accepted without the pre-snapshot, and independently unreadable targets still require the post-snapshot to establish unchanged state.

## 6. Independent administrator comparison

Run the same read-only snapshot SELECT after the client run and save `work/security/after.json`. Then:

```sh
node scripts/security/finalize.mjs work/security/before.json work/security/after.json work/security/client-run.json work/security/final-report.json
```

Requires all 38 unique required cases, real-network transport label, matching starting digest, valid chronology, and identical full baseline/fixture/member/Auth/policy/grant/owner/RLS state before/after. Expected status: CLIENT_AND_ADMIN_SNAPSHOTS_MATCH. This trusts the operator-attested SQL-export provenance; it is not independent cryptographic proof of execution. It does not detect transient concurrent changes that were restored between snapshots.

Limitations remain explicit: no production validation/migration, no allowed shared DELETE policy test, no private write regression suite, no peer-edit behavior test, no id/created_at attack cases, no token-expiry/concurrency stress and no browser desktop/mobile smoke. Successful SQL setup or local simulation cannot fill these evidence gaps.

## 7. Controlled cleanup proposal and final verification

Only after live finalization:

```sh
node scripts/security/prepare-sql.mjs cleanup work/security/after.json work/security/final-report.json > work/security/cleanup-proposal.sql
```

The generator refuses absent/mismatched finalized evidence. It does NOT execute SQL. Preview the exact proposal and obtain explicit destructive cleanup approval before applying it. Only the three bba60000 disposable shared rows are included. Each DELETE matches every snapshot field: UUID, household, creator, exact title/completed and created_at; each returns the deleted row. The transaction locks test tables, asserts exact one-row identities and counts, protects the baseline, private rows, memberships and Auth identities, and asserts exactly one shared baseline remains. No CASCADE, TRUNCATE, policy changes, account/membership deletion or broad household deletion.

Any mismatch/error before commit requires ROLLBACK, not relaxed criteria. After a successful commit, restoration would require separate approval and exact reviewed fictional snapshots. Keep DELETE RETURNING output as evidence; compare metadata independently. Memberships and all three test accounts are intentionally retained.

Run the snapshot SELECT again, save `work/security/after-cleanup.json`, and verify:

```sh
node scripts/security/verify-cleanup.mjs work/security/after.json work/security/after-cleanup.json work/security/final-report.json work/security/cleanup-report.json
node scripts/audit-html.mjs
```

Expected cleanup report status CLEANUP_AND_FINAL_METADATA_MATCH: shared baseline 1, private baselines 2, memberships 2, Auth users 3, unchanged policies/grants/RLS. Review returned DELETE rows separately. Snapshot freshness applies to live preflight; final comparisons require chronology but keep older evidence usable.

## Evidence and permanent logging

Local output is ignored under work/ and created with restrictive permissions for JSON reports. Reports contain fictional fixture IDs, pseudonyms, methods, statuses, SQLSTATE, timestamps and evidence digests, never credentials or full response bodies. Do not blindly commit artifacts; review/redact first. Append actual commands, observed results, errors/corrections, counts, approval scope and evidence locations to DEVELOPMENT_LOG.md. Update SECURITY_TEST_REPORT.md only with observed outcomes; keep prior historical statements intact and add dated progress notes.

A syntax PASS, simulation PASS, successful ordinary request, matching admin snapshot and approved cleanup are distinct milestones. Explain each separately when teaching this procedure.


## Local execution update — Entries 193–195

The user's Mac now runs Node v24.22.0. Use LOCAL_TEST_WALKTHROUGH.md for the private hidden-input launcher and staged execution. run.mjs now supports --mode update (27 assertions; no INSERT/DELETE tests), independently finalized as UPDATE_CLIENT_AND_ADMIN_SNAPSHOTS_MATCH; that status cannot authorize cleanup. Full --mode live retains all 38 cases and its separate exact DELETE-denial approval gate. Twelve offline safety/simulation groups pass. No live client security test has run.

The sandbox is now populated and independently administratively verified (Entries 181–183); do not rerun empty-state setup/Auth provisioning. Fresh session evidence must be captured just before local execution. private-run.mjs reads the public publishable key and saved test passwords through hidden local TTY prompts, passes them only to the ordinary-user process environment, and creates credential-free local evidence. It is not a hosted secret vault. No password is requested in chat, shell arguments or source files. Downloading source alone executes nothing.
