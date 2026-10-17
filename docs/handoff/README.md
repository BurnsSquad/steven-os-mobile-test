# Burns Base: read this before continuing

Updated October 17, 2026 (America/New_York). See [the visual project map](project-map.svg) or [the responsive handoff page](index.html).

## Purpose

Build a household planner shared across accounts and devices while preserving the existing Steven OS files and private records. Adult members create/manage Tasks; child members create their own Activities and complete eligible assigned Tasks. Everyone can see shared planner items. A Household item finishes once; a Shared item needs each assigned contribution. Actual family identities and composition are not needed for development.

## How we got here

| Stage | Result | What proves it |
|---|---|---|
| Preserve original | Stable v122 `index.html` and older files protected; no personal migration | Stable index SHA256 `aecb177cdebe6eded90f5e5b9626e152fd677066b923e8b988ece2b83c6683f8` |
| Isolated sandbox | Fictional A/B/C identities, older private/shared test tables and policies | Provider snapshots; DEVELOPMENT_LOG entries181–183 |
| Original security suite | 27 UPDATE and38 full-suite checks independently finalized; separately approved cleanup | Entries213,216–218 and SECURITY_TEST_REPORT.md |
| Earlier device sharing | v132 A created, B saw/completed, A saw completion; C unrelated | Earlier Mac/phone reports plus independent saved-state evidence, through Entry239 |
| Planner rules/design | v133 disconnected interface accepted: child Activities, sibling visibility, Household once, Shared per-person | Entries244–257; five model groups and offline browser checks |
| New database | Six RLS tables, controlled RPCs, trusted roles, assignments and attributed completion installed | Entries258–261;59 local PostgreSQL checks and hosted SQL-role smoke |
| Current work | Connect v134 preview to these tables and verify actual sign-ins/device sharing | New integration log entries and evidence; do not mark live acceptance before it happens |

## Three websites: do not confuse them

- **Stable application:** root `index.html`, preserved. It is not replaced by planner work.
- **Earlier v132 live-sharing preview:** `preview/household/`; uses old generic-member `bb_test_*` tables. Earlier Mac/phone acceptance belongs to this preview only.
- **v133 design demo:** `preview/planner-demo/`; role switching is simulation, changes reset on reload, no database connection.
- **v134 connected planner:** `preview/planner-live/`; actual saved fictional-account passwords, database-backed role checks, new `bb_planner_*` tables. Integration status and URL belong in the newest log entry.

## Database and trust boundaries

Isolated project: Burns Base Security Sandbox, `wozynsftofkjqwlflosv`. New planner household `bba90000-0000-4000-8000-000000000001`. Separate fictional mapping: A adult, B/C child. This changes none of the older memberships; C remains unrelated in the old-table tests.

New tables: households, members, items, assignments, completions, events (all `bb_planner_` prefix). Browser reads are RLS-protected; browser direct writes are denied. Five public invoker RPCs call narrowly privileged private functions. Their restricted NOLOGIN/NOBYPASSRLS executor is not inherited by authenticated users. `actor_uid()` mirrors the inspected provider `auth.uid()` request identity without requiring managed-auth schema grants. Keep `bb_planner_private` outside exposed Data API schemas.

Installed migrations:20261017190546 (original schema),20261017191149 (managed-auth identity compatibility),20261017191200 (covering FK indexes). Current `database/planner/schema.sql` includes the identity fix for a fresh installation; do not rerun it on the installed database. The original managed-auth permission issue, correction and evidence are documented in Entry260. Final snapshot at19:12:40.249342Z confirmed all earlier records, Auth identities, memberships, policy definitions and captured grants unchanged. New planner had one household/three members and zero task/assignment/completion/event rows after rolled-back SQL smoke tests.

## Evidence levels

1. **Local model/mock browser:** checks UI/protocol behavior. It is not Supabase security proof.
2. **Local PostgreSQL:**59 checks include actual SQL/RLS and independent simultaneous connections. Auth is a documented local stub.
3. **Hosted SQL-role smoke:** passed against the actual installed database using trusted administrator request-claim/role simulation. Writes were rolled back. It is not actual password/JWT/PostgREST proof.
4. **Actual sign-in + device acceptance:** required for v134. Must use supported Auth sign-in, verify returned user identity, and show the same saved change in independent sessions. Earlier v132 acceptance cannot substitute.

## What to do next

1. Read the newest `docs/DEVELOPMENT_LOG.md` entry and `preview/planner-live/README.md`; use its exact current preview URL.
2. Confirm actual A sign-in, private-schema API exclusion, own membership role and planner list. Tokens/passwords stay out of logs, chat and repository. Never reset saved passwords to gain test access.
3. With A on Mac and B on phone: create a fictional Task for B, see it on B, complete on B, see completion on A. B creates a fictional Activity; A/C can see it, C cannot edit/complete it.
4. Check Household once and Shared contributions from B/C; verify one versus separate completion attribution. Confirm server failures are shown clearly, stale edits refresh, and sign-out clears the page.
5. Record exact observed results and an independent provider snapshot. Preserve any new acceptance rows until an exact cleanup is separately approved.
6. Real onboarding, production data/hosting and broader Steven OS migration require a later concrete review. Delete/reopen/cancel/scheduling and reassignment after contributions are not enabled.

## Security item: deliberately deferred by the user

Provider organization plan is Free. Current [Supabase password-security documentation](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) says leaked-password protection requires Pro or above. User explicitly chose **keep sandbox Free for now**. No paid upgrade or Auth setting change is authorized by that choice. Keep this item visibly pending before real household use; do not report it enabled. It does not block fictional sandbox integration work.

## Source and operations

Repository: BurnsSquad/steven-os-mobile-test. Review branch: `codex/household-security-audit-20261016`; draft PR1 remains unmerged. Existing Git integration can create automatic previews. Dedicated preview deployments must upload only reviewed planner assets, never overwrite stable index, alter production aliases or include secrets.

Useful paths: `docs/DEVELOPMENT_LOG.md` (permanent sequence), `docs/SECURITY_TEST_REPORT.md` (evidence limits), `database/planner/README.md` (SQL/RPC contract), `database/planner/tests/hosted-result.json` (installed-state result), `scripts/` (checks), `preview/planner-live/` (connected UI). Raw snapshots stay in ignored `work/security/`. Rollback SQL is a reviewed proposal, not authorization to delete objects or records.
