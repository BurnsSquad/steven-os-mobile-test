# Start here — current Steven OS handoff

Current preview v157: https://steven-os-mobile-test-gd6w2pcxg-burns6.vercel.app/

## Where the work is

Repository: BurnsSquad/steven-os-mobile-test. Active implementation branch: `codex/household-security-audit-20261016`, draft PR #1. The draft is not merged into main. A new developer should read this branch rather than assume main contains the current preview. For collaboration, create a separate feature branch from the current implementation head; review changes together before combining them. Do not force-push the shared branch or change production as part of setup. Family onboarding is paused until the owners can do it together.

Generic development updates 302 onward live under `docs/development-updates/`. The older historical development log has been left unchanged. Older handoff material describes earlier stages; use this current status and the newest numbered update first.

## What is connected

- Original eleven-tab layout and private workspace/revision saves, with private HTML/JSON recovery downloads.
- Separate parent-requested shared household JSON export for Tasks/Activities/completions, Family-visible calendar, groceries, routine settings/templates, usernames, Goals/milestones and shared priorities. Parent-only Businesses have their own separate download. No Finance/private original data, personal priority-readiness choices, automatic restore or point-in-time snapshot claim.
- Canonical household Tasks/Activities, individual/household/shared completion, usernames and existing recovery workflow.
- Parent repeating routines with 12-hour Eastern times and future-template edits, also in original Household.
- Family/Parents/Private calendar events projected into all five original calendar views without copying them into private records.
- Parent Finance fact review, versioned revisions, paycheck drafts/calculation/approval, confirmed due-date calendar projection and an Overview summary. Current cash is parent-entered, not a bank balance query.
- Family-visible Goals/milestones: three milestones with four steps each, owner management, parent management of all, attributed completion/undo, progress ring and archive. Original private roadmaps remain separate.
- Parent-only shared Businesses: ventures, project tasks, department/project progress, completion attribution, version checks and archive. Same records appear above private legacy content in original Businesses and in the shared parent navigation. No automatic import or Finance coupling.
- Family-visible flexible priorities: each member manages their own, parents manage all and may create Family priorities, and completion attribution/history is retained. Personal readiness choices stay private to each account. The connected panel appears both in shared navigation and above the original private Priority Board; legacy priorities are not imported.
- Shared groceries for family add/pick, child-own edit, parent management/archive; same list in original Groceries. Pickup is not a financial transaction.
- Shared phone navigation remains visible while scrolling, labels the current section and keeps Task/Activity controls out of Groceries/Calendar/Finance. The original toolbar has a Shared groceries shortcut.
- A shared client refresh guard preventing simultaneous token refreshes or late old-session failures from clearing a newer session.

## Boundaries that must remain

Private original source/workspace stays owner-only. Other family accounts access shared modules, not the owner's entire original private dashboard. Original historical charts are preserved and labelled separately from current Finance calculations. Shared records never enter private original arrays or recovery exports. Immutable source files and private attachments must not be published. No passwords, tokens or privileged API keys in chat, logs or source.

Original legacy goals, businesses, flexible priorities and historical household/Kids data are not automatically shared. New connected Goals and priorities are included in the family download; parent Businesses use a separate parents-only download. Missing optional backup collections are not invented. Supabase Free remains selected; no banking, payment execution, production promotion or merge has been performed.

## Evidence

See [RELEASE_READINESS.md](RELEASE_READINESS.md) for the completed current-scope release evidence. The v157 Priority Board adds request tests, a dedicated three-context browser flow, shared-shell and original-source regression coverage, export tests and a hosted rollback SQL-role suite. The direct anonymous REST probe was network-unavailable and is not counted as live API evidence.

Earlier family planner/calendar acceptance was reported by the user. On v152 the user also confirmed cross-device shared grocery pickup and the correct pickup attribution. New work has hosted rollback SQL-role checks plus deterministic request tests and mocked multi-session/original-source browser checks. These are not fresh real-password/physical-device acceptance. Routine template edits preserve existing Task history; grocery test fixtures were rolled back. Session tests cover concurrency, delayed responses and sign-out/new-login isolation. All eleven original tabs and five calendar views are part of regression coverage, not certification of every legacy control.

## Next actions requiring the family

1. The v152 real-device grocery add/pick/attribution check is complete. Do not repeat it merely to prove the same database sharing. Verify new UI changes only when needed; keep passwords on the website.
2. Parents verify current financial sources and cash snapshot through the Finance checklist before relying on a paycheck result. Do not let a developer infer confirmation from dated documents.
3. Resume collaborator onboarding together; confirm the collaborator can read the active branch before granting wider infrastructure access or starting parallel edits.
4. Businesses audience was confirmed parents-only and implemented in v155. Goals/milestones were confirmed family-visible, manage-own, parents-manage-all and implemented in v156. The connected Priority Board and the two download scopes were implemented in v157. Private records are not migrated automatically.

See database/planner/ORIGINAL_OS_COMPATIBILITY.md, SHARED_GROCERIES.md, FINANCE_CURRENT_WORKFLOW.md and CLIENT_SESSION_RELIABILITY.md for the current implementation boundaries.

## Latest update — Entry 310

Parents-only Businesses is installed in the hosted database and deployed in v155. Rollback SQL checks cover two parents, child/other-household/no-identity denials, retries, stale writes, archive, completion attribution/undo, direct-write denial and audit. Post-check found zero business fixtures retained. Two API tests and the new two-parent mocked browser flow pass; original-source/shared-shell/recovery regressions also pass. Existing security advisor findings are unchanged. No fresh physical-device business acceptance is claimed.

## Latest update — Entry 311

Family Goals/milestones installed and connected in v156. Hosted rollback SQL verifies family visibility, child-own writes, sibling write denial, both-parent management, 3x4 shape, preserved completion on milestone edits, attributed completion/undo, stale/idempotent writes, archive and foreign/no-identity/ACL denial. No test goals/audit fixtures retained. Two new request tests and the mocked family goal flow pass; original-source/shared-shell/recovery browser regressions and 19 targeted request/session/export tests pass. Existing advisors unchanged. A fresh physical-device goal check remains unverified.

## Entry 312 — full-roadmap verification

Expanded hosted rollback SQL and mocked browser checks pass all 12 completions, independent parent/sibling readback, 100% progress, 92% after reopening and 100% on recompletion. Sibling controls remain read-only. Server attribution, no-op version stability and audit are checked; no fixtures retained. This completes agent-run acceptance; actual family JWT/device acceptance remains unverified. v156 runtime/deployment unchanged.

## Entry 313 — priorities and scoped downloads

The family Priority Board is installed and deployed in v157. Household members can see priorities, manage their own and keep their own readiness choices private; parents can manage all and create Family priorities. Hosted rollback checks pass permissions, cross-household isolation, server completion attribution, version conflicts, archive locking and direct-write denial, with zero retained fixtures. The family download now includes exact-field Goals and priorities, while parents-only Businesses have a separate exact-field download. Original private priorities, Goals and Businesses stay separate.
