# Finance planning intelligence requirements

Supplement to the current Finance handoff, sourced from the owner's additional October 17 behavior specification. This records requirements; it does not claim an automated planning engine, linked bank feed, scenario UI or payment execution is implemented. The existing Finance preview remains a read-only reference. Preserve the original OS layout/tabs/charts when integrating these behaviors.

## Required behavior

1. Separate Required, Stability and Optimization layers. Minimum debt is a required obligation even though its subtraction follows living/buffer in the default planning sequence. Optional payments must never be labeled required.
2. A genuinely received or explicitly entered paycheck starts a versioned draft for its receiving account and actual planning window. Expected deposits remain expected, not usable cash. Repeated ingestion of the same deposit must not duplicate a plan.
3. Include active dated obligations due in the window. Exclude completed/paid obligations; retain scheduled/pending obligations while avoiding a second reserve for money already reflected in bank available balance. Permanent bill definitions and temporary arrangement installments remain distinct; remaining provider balances are not automatically all due.
4. Store living baseline, recent actual and current planned amount separately. Preserve realistic essentials; do not reduce them merely to manufacture positive surplus. Buffer targets are protected requirements; explicitly report any shortfall. Protected rollover is a separate purpose-bound record, not the normal buffer.
5. Distinguish visible bank balance, committed money, protected money and unassigned money. Use a single obligation/reservation identity across ledger, minimum-debt and scenario views to prevent double counting. Transactions already reflected in balance must not be subtracted twice. Unknown inputs block a definitive surplus; negative amounts become explicit shortfalls, not zeroed or hidden.
6. Compare optional Safe, Balanced and Aggressive scenarios only after required needs/stability are known. Show ending balance, debt payment, expected utilization, payment eliminated, next-check impact, liquidity tradeoff and unresolved facts. Aggressive does not silently waive essentials/buffer. Exceptions require an explicit, explained adult override. No scenario is a payment instruction or bank action.
7. Consider APR, utilization, payment elimination, next-check burden, payoff cash, liquidity and reporting timing together. Compare cards rather than sending all surplus to a fixed card. Expected utilization is an estimate requiring confirmed balance/limit/payment and accounting for known pending changes.
8. Maintain confidence states Confirmed, Expected, Scheduled, Pending, Paid and Needs confirmation. Separately model lifecycle Superseded, period assignment Next Check, allocation Optional and protection Protected; these are not mutually exclusive facts on one status enum.
9. Linked finance data, if connected later, is evidence to reconcile with household context. Matching/review must not convert an installment into a permanent recurring bill, duplicate pending/posted transactions, or treat available credit as cash. No bank integration is authorized merely by receipt of this spec.
10. Prefer fresh, specific evidence and show disagreements. Keep original source, timestamps, confirmation and supersession history; do not silently choose between conflicting values. The October 18 addendum resolves the earlier formatting omission: (1) current provider/linked evidence, (2) current explicit family confirmation, (3) current approved check plan, (4) Reference Library default, (5) historical records. This is context-aware, not a blind overwrite rule: current family confirmation can qualify or override incomplete, stale, pending, misclassified or context-free provider data. Record the chosen source and reason; unresolved conflicts remain Needs confirmation and are excluded from uncertain optional calculations.
11. Every recommendation gives a concise household-specific reason. Mid-cycle changes create a new draft revision, explain the change, and reduce lower-priority allocations first: extra debt, savings, optional spending, then buffer only if necessary. Do not shame household spending or defend an outdated plan.
12. End-of-check reconciliation compares actual payments, pending obligations, living, transfers, ending balances and newly discovered commitments. Only confirmed actual rollover may carry forward; spent planned rollover loses protected status. Show rather than erase deviations.
13. Family approval is explicit and revision-bound: draft → reviewed → approved. Material changes invalidate prior approval and create a new reviewable version. Approval does not execute a transfer/payment. Never treat approval contained in a historical document as approval of a future live plan.

## Acceptance criteria before shipping automatic drafts

| Case | Expected result |
| --- | --- |
| Payday boundary / next-payday bill | Current window ends the previous local day; future bill excluded unless explicitly pre-funded. |
| Expected versus received money | Only verified received funds/confirmed actual rollover and intentional releases count. |
| Scheduled/pending/posted transition | One obligation/transaction identity, no duplicate reserve/debit. |
| Debt minimum already in bill list | Required once, not again in minimum-debt allocation. |
| Missing current balance, payoff, due date or living actual | Needs confirmation with exact missing inputs; no fabricated spendable amount. |
| Insufficient cash | Visible shortfall and optional allocations withheld; no silent zero buffer or underfunded food. |
| Temporary arrangement | Current installment reserved; remaining balance separated from normal bill. |
| Mid-cycle correction | New revision with reason; old plan/history preserved; prior approval invalidated. |
| Card alternatives | Comparison with uncertainty and liquidity effects; no guaranteed bureau/reporting result. |
| End-of-cycle rollover | Actual confirmed remainder only; no phantom planned carryover. |
| Family approval | Specific adult approval required; children cannot read or modify financial plans; no bank execution. |
| Reimport/retrigger | Idempotent source/paycheck identity, original history retained. |

## Implementation status

The dated source documents and normalized requirements are retained privately behind the existing adult-only Finance RLS. The missing-rank clarification is resolved by the October 18 addendum; the prior requirements/clarification remain as superseded versions. Required fact provenance includes value, source_type, source_timestamp, verified_at, confidence/needs_confirmation, effective dates, superseded_by and context_note. The original financial figures and existing references are unchanged. No new schema, financial allocations, automated drafts, approval actions, bank connections, payments or UI redesign were performed for this requirements update. Existing calendar/tab/graph integration remains pending the latest original OS HTML and private backup.


## October 18 addendum acceptance requirements

- Fresh factual provider evidence normally governs balances, due dates, minimums, limits, current statements and posted payment status; document family context separately.
- A temporary arrangement qualifies the amount required this check without changing a genuine total account balance or overwriting the permanent bill definition.
- A newer current minimum creates a dated revision and flags the old reference; historical calendar values remain historical.
- Spent rollover is removed from current usable/protected cash even if the approved prior plan expected it.
- Record source timestamps separately from the time the OS accepts a fact. Never claim provider verification for a family/document assertion.
- Source hierarchy does not grant bank-linking or payment authority. Drafts still need revision-bound family approval.

No automated conflict resolver or draft/scenario engine is claimed implemented by this specification update. No UI redesign; original OS/calendar/tabs/charts remain the integration target.
