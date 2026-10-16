# Private local test walkthrough

Prepared after verifying the user's macOS 14.3 / x86_64 and Node v24.22.0. This route uses the reviewed code in a separate downloaded folder. Do not open/replace stable index.html, import backups, change browser storage, merge PR #1 or connect production.

## What is ready

The sandbox has three confirmed fictional Auth users, two private baselines, two A/B memberships, four shared test rows and eight reviewed policies. The assistant independently verified setup through the sandbox SQL connector. Auth user passwords remain private. No ordinary-user live test has run yet.

private-run.mjs prompts for the sandbox public publishable key and the saved A/B/C passwords through hidden Terminal input. They are used in local memory/child-process environment, never command arguments, shell history, report files or repository files. This is private interactive input on the user's Mac; it is not a hosted secret vault and does not promise protection from privileged local process inspection. Tokens are not persisted; Auth sessions may survive until expiry. No administrative key is needed or accepted.

## Stage 1: obtain the source, then offline checks

Download the exact pinned ZIP link supplied in chat and extract it to a new folder. Do not overwrite an existing personal/project folder. Download/extraction executes no project code or database request. The ZIP is the unmerged review commit, not main.

Once the actual extracted folder is identified, use Terminal there and run:

```sh
node scripts/security/safety.test.mjs
node scripts/audit-html.mjs
```

Expected: twelve offline groups pass, and all 167 inline HTML scripts parse with stable index hash unchanged. These checks do not contact Supabase or ask for passwords. No npm install, dependencies, service key or sudo needed.

## Stage 2: reviewed session evidence and public connection key

The assistant will freshly query the exact sandbox and publish only fictional fixture/security metadata as docs/evidence/sandbox-session.json on the review branch, then provide its immutable raw.githubusercontent.com commit URL. Session fields: schema=1, project_ref=wozynsftofkjqwlflosv, policy_reviewed=true, snapshot=the independently verified administrative query result. No password, secret/service key or token belongs in this session document.

The launcher accepts only a 40-hex-commit URL under this repository's exact docs/evidence/sandbox-session.json path, refuses redirects/alternate origins/queries, and validates counts/identities/privileges/freshness. It checks again after password entry; evidence older than ten minutes stops before login/writes. If that happens, obtain a new snapshot rather than relax the guard.

Use the sandbox's public key beginning sb_publishable_ when the hidden prompt requests it. Never paste an sb_secret_ key or legacy privileged JWT. Public connection keys are different from account passwords and do not bypass RLS. Do not post any credentials in chat or put them into shell commands.

## Stage 3: UPDATE only, no deletion

After offline checks and a fresh session are ready, the assistant supplies the exact command in this form (placeholder below is explanatory, not a runnable URL):

```sh
node scripts/security/private-run.mjs --mode update --session-url PINNED_SESSION_URL
```

This is an authorized UPDATE-only operation. The launcher describes the target/mode, then asks privately for the public key and A/B/C passwords. Nothing is echoed at the prompts; press Return after each entry. Ctrl+C cancels; terminal raw mode is restored on normal completion/cancellation. Do not type passwords before the program displays a private-input prompt. If the Terminal is left with abnormal echo after an abrupt kill, stop password entry and ask for recovery guidance.

Expected: 27 client assertions covering ordinary A/B/C authentication, A/B read baselines, authorized title/completed changes, immutable creator/household denial, existing unrelated-household filtering, exact known-state restoration and final visible baselines. No C INSERT test, DELETE request or cleanup is included in this mode. Protected baseline IDs are never write targets. Report status remains UPDATE_CLIENT_CHECKS_PASSED_ADMIN_VERIFICATION_PENDING.

The local evidence folder is printed under work/security/<timestamp>/ in the downloaded repository. It contains only the fictional before snapshot and credential-free client-report.json, with restrictive file permissions. Return the report for independent admin comparison; do not send passwords/keys/Terminal input. The assistant must capture a post-snapshot and compare all fixtures/memberships/Auth/policy/grant metadata. A successful UPDATE-only comparison returns UPDATE_CLIENT_AND_ADMIN_SNAPSHOTS_MATCH and cannot authorize cleanup.

If a test fails, it stops. Only exact known states created by the runner are restored. Unknown row/ownership changes are left for investigation, not overwritten. No automatic INSERT repair or cleanup. Review evidence before retrying.

## Stage 4: DELETE denial and unrelated C isolation

Separate from UPDATE approval, review the exact disposable-row DELETE attempts: A deletes its ...0001 bba60000 fixture, B its ...0002 fixture, and C attempts A's same fixture. Intended result is permission denial; wrong permissions could actually delete the target, so prior exact approval is still required.

Only after that approval and a new fresh session may the full 38-case suite run with --mode live --approved-delete-denial. The flag is an accidental-execution guard, not a substitute for approval. The full suite repeats UPDATE baseline checks to integrate the approved later tests with a fresh before/after comparison. No shared DELETE policy is enabled, and no cleanup executes. Preflight remains default if no mode is supplied.

Full real client success plus independent administrator comparison is required for CLIENT_AND_ADMIN_SNAPSHOTS_MATCH. UPDATE-only reports cannot satisfy the cleanup generator.

## Stage 5: exact cleanup and final checks

Follow SECURITY_RUNBOOK.md's finalized-evidence cleanup proposal workflow. Before executing, review the exact three bba60000 disposable rows and SQL and obtain destructive cleanup approval. Keep protected shared/private baselines, both memberships and all three test users. Verify DELETE RETURNING output, fresh post-cleanup metadata and stable index hash. Do not remove the downloaded folder/evidence until results are reviewed; deleting local test files does not undo database changes.

All tests/procedures are separately recorded in DEVELOPMENT_LOG.md. Twelve offline test groups are code evidence, not a claim of live Supabase enforcement.
