# Start here — current Steven OS handoff

Current preview v152: https://steven-os-mobile-test-m9zn2omxd-burns6.vercel.app/

## Where the work is

Repository: BurnsSquad/steven-os-mobile-test. Active implementation branch: `codex/household-security-audit-20261016`, draft PR #1. The draft is not merged into main. A new developer should read this branch rather than assume main contains the current preview. For collaboration, create a separate feature branch from the current implementation head; review changes together before combining them. Do not force-push the shared branch or change production as part of setup. Family onboarding is paused until the owners can do it together.

Generic development updates 302 onward live under `docs/development-updates/`. The older historical development log has been left unchanged. Older handoff material describes earlier stages; use this current status and the newest numbered update first.

## What is connected

- Original eleven-tab layout and private workspace/revision saves, with private HTML/JSON recovery downloads.
- Canonical household Tasks/Activities, individual/household/shared completion, usernames and existing recovery workflow.
- Parent repeating routines with 12-hour Eastern times and future-template edits, also in original Household.
- Family/Parents/Private calendar events projected into all five original calendar views without copying them into private records.
- Parent Finance fact review, versioned revisions, paycheck drafts/calculation/approval, confirmed due-date calendar projection and an Overview summary. Current cash is parent-entered, not a bank balance query.
- Shared groceries for family add/pick, child-own edit, parent management/archive; same list in original Groceries. Pickup is not a financial transaction.
- A shared client refresh guard preventing simultaneous token refreshes or late old-session failures from clearing a newer session.

## Boundaries that must remain

Private original source/workspace stays owner-only. Other family accounts access shared modules, not the owner's entire original private dashboard. Original historical charts are preserved and labelled separately from current Finance calculations. Shared records never enter private original arrays or recovery exports. Immutable source files and private attachments must not be published. No passwords, tokens or privileged API keys in chat, logs or source.

Original legacy goals, businesses, flexible priorities and historical household/Kids data are not automatically shared. Missing optional backup collections are not invented. Supabase Free remains selected; no banking, payment execution, production promotion or merge has been performed.

## Evidence

Earlier family planner/calendar acceptance was reported by the user. New work has hosted rollback SQL-role checks plus deterministic request tests and mocked multi-session/original-source browser checks. These are not fresh real-password/physical-device acceptance. Routine template edits preserve existing Task history; grocery test fixtures were rolled back. Session tests cover concurrency, delayed responses and sign-out/new-login isolation. All eleven original tabs and five calendar views are part of regression coverage, not certification of every legacy control.

## Next actions requiring the family

1. Open the current preview on two devices with different saved family accounts. Add a clearly labelled test grocery on one; mark it picked up on the other; verify attribution back on the first after refresh. Keep passwords on the website.
2. Parents verify current financial sources and cash snapshot through the Finance checklist before relying on a paycheck result. Do not let a developer infer confirmation from dated documents.
3. Resume collaborator onboarding together; confirm the collaborator can read the active branch before granting wider infrastructure access or starting parallel edits.
4. Decide the next legacy collection to share explicitly. Do not expose private collections merely because their UI is restored.

See database/planner/ORIGINAL_OS_COMPATIBILITY.md, SHARED_GROCERIES.md, FINANCE_CURRENT_WORKFLOW.md and CLIENT_SESSION_RELIABILITY.md for the current implementation boundaries.
