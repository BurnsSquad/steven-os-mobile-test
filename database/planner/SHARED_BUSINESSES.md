# Parent-only shared Businesses — v155

The user selected Businesses and confirmed “Parents only for now.” New shared records are visible/editable by adult members of the same household. Child accounts have no navigation entry and no database read/write permission. Existing private original business records remain separate and are not imported automatically.

## User workflow

Open Businesses in shared navigation or the original Businesses tab. Add a venture with its current project, stage, optional target release date and notes. Add project tasks with one of the original seven departments and an optional due date. Both parents can edit, complete/reopen and archive. Completion shows the server-derived parent's username. The progress ring and department/project summaries use active tasks. Targets are estimates; percentages do not authorize launches. Archive preserves records and makes them read-only. Save edits before switching original tabs.

## Implementation

- public.bb_business_ventures and public.bb_business_tasks: RLS parent read; no authenticated direct writes.
- Checked public invoker RPCs delegate to a narrow non-login writer, fixed search_path and membership authorization. Household/creator immutable, no delete grant, strict payload keys, version conflicts, create retries, server actor/timestamps and private change audit.
- Self-contained businesses.mjs is used in both surfaces. The original opaque frame uses a nonced command allowlist; no token enters the frame. Connected records are not stored in legacy arrays.
- Lists refresh every 15 seconds while visible; polling preserves text and ignores responses older than a local mutation. A conflict keeps typed text for review; refresh/reopen before retrying.
- No automatic Finance/bank calculation, spending, calendar event or release operation. Parent business records are excluded from the shared-household JSON download and private original backups. No business restore/import feature is claimed.

## Evidence

shared-businesses-test.sql passed on hosted Postgres inside a rolled-back transaction: two-parent peer read/write, child/foreign/missing-identity denial, retries, stale/blank/null/unknown-field guards, attributed completion/undo, archive, direct insert/update denial, private audit and ACLs. Post-check found zero retained business ventures/tasks/audit fixtures.

businesses-api.test.mjs: two deterministic request tests. businesses-smoke.cjs: mocked two-parent/child creation, read, completion/undo, progress, stale text, archive, literal rendering, mobile fit and clearing. Original-source and shared-shell browser regressions exercise the new bridge/navigation alongside prior connected features. These are simulated transports/database roles, not fresh ordinary-password/device acceptance.

Preview: https://steven-os-mobile-test-mz759zm20-burns6.vercel.app/
