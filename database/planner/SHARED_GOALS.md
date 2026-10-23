# Family Goals and Milestones — v156

Confirmed audience: everyone sees household goals; each member manages their own; parents manage all. This applies to new connected records. Existing original private goals/roadmaps are not imported or exposed automatically.

## Workflow

Open Goals & Milestones in shared navigation or original Goals. A child creates for themselves; parents can create for any household member. Owner stays fixed after creation. Add a title/description, name each milestone and its four steps, and complete/reopen individual steps. Progress is computed from all 12 steps. Milestone text edits preserve completion and attribution. Archive preserves records and makes the goal read-only. Save edits before changing original tabs.

No task, routine, calendar, business or financial record is created automatically by a goal. New goal data is not included in the existing shared-household download or private original backup; the website labels that scope. No goal restore/import feature is claimed.

## Database and client

public.bb_goal_roadmaps has membership-scoped family SELECT under RLS; no authenticated direct insert/update/delete. Checked public invoker RPC delegates to a narrow non-login writer with fixed search_path, current membership/owner checks, immutable household/owner/creator, advisory/row locks, versions, create retries, strict payload keys, 3x4 shape and server-derived completion attribution. Private goal_changes records changes; no browser audit access.

The same self-contained goalsPanel runs in shared shell and original opaque frame. The bridge uses source/origin/nonce/epoch checks and list/write command allowlist. Polling every 15 seconds while visible preserves typed edits and ignores snapshots older than local mutations. Conflicts retain text; refresh/reopen the edit before retrying. Children see siblings’ goal steps disabled, not writable controls. Backend checks remain authoritative.

## Evidence

Hosted shared-goals-test.sql passed inside a rollback: own child writes, sibling reads/denials, both-parent management, parent creation for child, 3x4/blank/index/null validation, immutable owner, completion preservation/attribution/undo, idempotent create, stale denial, archive, direct write and ACL denial, other household/no identity denial and private audit. Post-check goals/audit zero.

Two goals API request tests pass. Mocked three-context browser covers own creation, sibling read-only, parent milestone/step edits, completion/undo, progress, preserved completion, stale edit text, archive, literal rendering, mobile and clearing. Shared-shell and original-source regressions exercise navigation and original Goals bridge alongside preserved eleven tabs and five calendar views. Recovery/session/export tests remain passing. These are database-role simulations and mocked browsers, not new password/device acceptance.

Current preview: https://steven-os-mobile-test-17w73hdix-burns6.vercel.app/

## Entry 312 — full-roadmap verification

Expanded hosted rollback SQL and mocked browser checks pass all 12 completions, independent parent/sibling readback, 100% progress, 92% after reopening and 100% on recompletion. Sibling controls remain read-only. Server attribution, no-op version stability and audit are checked; no fixtures retained. This completes agent-run acceptance; actual family JWT/device acceptance remains unverified. v156 runtime/deployment unchanged.
