# Shared groceries — v151

A live household grocery list is available to all signed-in household members through Groceries in the shared navigation. The owner's original Groceries tab shows the same canonical list above existing private lists and spending charts. Private records are not imported, overwritten or shared automatically.

Everyone can add an item with optional quantity/size and mark it picked up or still needed. Pickup attribution uses the authenticated actor. Children can edit their own additions; parents can edit any household item and archive it. Archived items remain visible in a separate read-only view with audit history retained. There is no hard-delete or bulk cleanup operation.

The list is not a spending ledger: pickup does not imply a price, bank transaction, Finance expense, budget deduction or payment. Prices and actual expense reconciliation remain separate work.

`bb_grocery_items` has household-member SELECT RLS and no direct browser write grants. A public invoker RPC calls an unexposed fixed-search-path function owned by a narrow NOLOGIN/NOBYPASSRLS writer. Each command verifies current membership, role/ownership and expected version. UUID-based create retries are idempotent for matching content; stale versions reject instead of overwriting. Household/creator identity cannot be edited; private audit rows are not browser-readable.

The UI renders record text literally, refreshes while visible, preserves typed text during list refresh and stale failures, and clears on sign-out. An in-flight older list response cannot overwrite a later mutation. Original iframe requests use the established nonce/source/origin checks and a list/write allowlist; no session token enters the iframe. Shared rows never enter original private workspace arrays or recovery downloads.

Validation: hosted rollback SQL-role checks cover child add/own edit, sibling visibility and pickup, denied sibling edits/child archive, parent management, attributed undo, stale/null validation, archive immutability, direct write denial, outsider/no-identity denial, idempotent create, history count and ACLs. Zero test rows remain. Mocked family browser checks exercise cross-context pickup, roles, stale text, archive, literal names/mobile and clear; original-source browser checks add/pick through the preserved Groceries tab and verify private export exclusion. Existing shared planner regression also runs. Automated tests do not claim fresh ordinary-password or physical-device acceptance.

The security advisor retains only the previously known optional password-protection warning and intentional private routine-occurrence INFO. No new grocery warning. Supabase Free unchanged; no production promotion or merge.
