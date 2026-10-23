# Current Finance workflow — v144

Amanda's three source documents remain attributed private references. Current Finance is now a parent-only manual workflow in the original Finance tab and shared app Finance Center. Original owner-only ledger, spending/category charts and private sections remain below a clear historical boundary. No private source, balances, family identifiers or import payloads are public assets.

Parents can revise facts, add dated bills, create a paycheck draft, preview server-calculated totals, save/reopen drafts, and approve a specific reviewed revision. All changes retain before/after history, adult actor, reason, dates and versions. New family confirmations supersede prior facts without replacing their payloads. Source documents and architectural rules are immutable through these controls. Both parents have Finance access; children, unrelated households and anonymous users do not.

## Calculation and review rules

Received payday through the day before next payday is the window. The dated cash snapshot cannot be future or outside that window and belongs to an eligible household spending account. Enter one snapshot: never add a paycheck, rollover or transfer again if already included. Expected deposits, credit, business cash and unreleased savings are not additional usable cash. Negative cash/account balances can represent an overdraft; a shortfall blocks approval.

Only dated current bill instances for that account/window are reserved. Missing accounts, dates and amounts are flagged. Confirmed paid rows remain visible but do not reserve remaining cash. Scheduled/pending bills remain reserved unless a verified fact says they were already deducted from this exact cash-snapshot date. A missing/mismatched deduction date never silently removes an obligation.

Bills and minimum debt count once. Card/loan/installment balances and arrangement remainders are not added again as bills. Adults attest the dated list is complete; recurring due dates and minimums are not invented. Realistic remaining food, gas, laundry and other living stay separate from historical baselines. Buffer and other protected money are reserved. A reduced buffer needs an explicit acknowledged reason.

Optional utilization payments, savings and extra payoff follow required needs/stability. Unknown inputs, uncertain facts, incomplete review, shortfalls and over-allocation block approval and optional scenarios. Safe/Balanced/Aggressive views are illustrative surplus-capacity alternatives, not selected debt payments or provider forecasts. Unknown APR, payoff, reporting and transaction data are not guessed.

Amounts are integer cents in the server. Allocation ring components match the plan table exactly; reconciliation shows allocations + unassigned - shortfall = entered cash. Unconfirmed cash is labeled as entered, not confirmed. Charts describe a draft and remain distinct from live bank balances.

## Source, access and history

All writes use adult membership checks, a narrow NOLOGIN/NOBYPASSRLS writer, fixed search path and transactional RPCs. Direct browser writes are denied. Household locking serializes fact revisions and plan saves. Versions reject stale edits; source fingerprints prevent approving against changed facts. Approval records a family decision only; it sends no money.

Manual facts record family confirmation, observation time and context. They do not impersonate provider evidence. A parent must explain conflicts rather than silently overwrite source priority. The existing source-trust addendum remains intact.

bb_finance_records preserves prior fact payloads and supersession links. bb_finance_check_plans stores the latest plan revision and calculated source snapshot. bb_finance_changes retains immutable before/after snapshots and attribution. UI shows the latest 100 plans/changes; older history remains stored. Source reads are paginated so revision growth does not silently hide current facts.

Refresh preserves plan inputs. Original-tab navigation retains an unsaved plan in frame memory until sign-out and requires a fresh preview. Shared Finance records never enter private original OS arrays, revision snapshots or HTML/JSON recovery exports.

## Workspace and chart mapping

| Source area | Connected behavior |
| --- | --- |
| 00 Command Center | Dated selected-plan brief, account, cash/commitments and confirmation state. |
| 01 Current Check Plan | Editable draft, window obligations, living/protection/optional inputs, exact-cent allocation ring, reconciliation and recorded approval. |
| 02 Reference Library | Fact revision editor, dated bill creation, source library and revision history. |
| 03 Monthly + Annual | Existing source section and original charts retained. Forecasts/debt projections stay unavailable without verified balances, terms and longer-range inputs. |
| Original Finance and Everyday Spending | Owner-only ledger/charts remain explicitly historical; they are not silently mixed into current paycheck figures. |

This completes manual current-plan integration, not bank-feed linking, payment execution, full transaction reconciliation/import or complete monthly/annual forecasting. Current balances are not fabricated to unlock a dashboard.

## Verification and installation

finance-workflow.sql consolidates the additive schema/functions for a fresh setup above the existing planner/reference schema. Hosted migrations: finance_parent_review_and_paycheck_plans; finance_new_dated_bill_and_account_revision; finance_validation_and_account_scope_guards; finance_cash_snapshot_deduction_and_uncertainty; finance_nullable_payment_and_snapshot_safety. Do not rerun the consolidated file over installed objects.

finance-workflow-test.sql creates temporary fictional households/amounts, uses existing identities as SQL-role actors, then rolls back. Covers exact cents, dates, paid/pending, deduction snapshots, minimums once, unknown/negative cash, approval gates, immutable facts, source/version conflicts, new/inactive bills, attribution, child/foreign isolation and ACLs. These are administrator-driven role tests, not actual password/JWT acceptance.

finance-workbench-smoke.cjs uses two mocked parent contexts for preview, decimals, chart/table agreement, draft/approval, conflicts, revisions, new bills, literal text, mobile and clear/reopen. original-os-smoke.cjs verifies the actual original-source frame bridge, draft save, unsaved inputs across tabs, mobile and exclusion from private snapshots, plus prior tab/calendar/planner/export regressions. No real family credentials are collected.

Protected imported source count/fingerprint remains unchanged. No fixture plans/history remain. Security advisor retains only the existing optional password warning and intentional private occurrence INFO.

