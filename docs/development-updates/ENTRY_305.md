# Entry 305 — Shared household groceries

v151 adds a live household grocery list to shared navigation and the original Groceries tab. Everyone can add items with optional quantity/size and mark picked up or still needed, with authenticated pickup attribution. Children edit their own additions; parents edit/manage/archive household items. Archived records stay read-only in their own view; no hard delete. Pickup does not create spending, Finance deductions or payment records.

Installed additive membership-scoped groceries and private history tables, explicit RLS/grants and one checked versioned RPC. The writer is a narrow private NOLOGIN/NOBYPASSRLS role; identity comes from the request, not caller fields. Expected versions reject stale changes, matching create retries do not duplicate rows, and immutable household/creator fields cannot be reassigned. Original grocery/spending records remain private and untouched.

Hosted rollback SQL-role checks pass own/sibling/parent behavior, foreign/no-identity denial, direct-write denial, pickup/undo attribution, retries, stale/null validation, archive immutability, audit count and ACLs. Zero grocery test rows/history remain. Security advisor has no new grocery findings; only previously known optional password-protection and intentional private routine INFO remain.

API scope/reply validation tests pass. Three-context grocery browser mock passes child add/own edit, sibling pickup, parent management, stale text preservation, archive/literal text/mobile/clear. Shared-shell browser mock exercises child add -> parent pickup -> child attribution and sign-out cleanup. Full original-source browser mock verifies Groceries bridge/add/pick and exclusion from private original data/backups, plus existing eleven tabs/five calendar views, routines, Finance, shared planner, mobile/recovery regressions. These are automated/SQL-role results, not fresh ordinary-password or physical-device acceptance.

Preview READY: https://steven-os-mobile-test-pmup8lhuk-burns6.vercel.app/

Documentation: database/planner/SHARED_GROCERIES.md. The shared list starts empty: no private historical list was copied. Free unchanged; no bank connection, financial confirmations, production promotion or merge. Generic update series continues without rewriting the historical log.
