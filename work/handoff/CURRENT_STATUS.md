# Burns Base / Steven OS — current handoff

Updated 2026-10-25 (America/New_York)

## What is operating

- Original Steven OS source, layout, tabs, charts and private records remain protected and separate.
- Shared planner uses real Supabase Auth, household membership, RLS and server-side completion rules.
- Tasks, Activities, calendar audiences, Goals & Milestones, parent-only Businesses and the parent Finance review workflow are connected in the preview planner.
- Parent Finance records and plan/history reads are returning HTTP 200 in the connected preview.
- The original layout is loaded as a private owner workspace; connected modules are integrated without copying private data into shared records.

## Current banking milestone

Banking is still a sandbox preview feature. The stable preview is:

`https://steven-os-mobile-test-banking-preview.vercel.app/preview/planner-pilot/`

Recent fixes:

1. `102ff27` — adapted Plaid functions to Vercel's Node `(req, res)` boundary.
2. `7373c68` — allowed the browser to call the app's own `/api/plaid/*` endpoint through CSP.
3. `94e9873` — added safe Plaid provider-code diagnostics; no secret values are returned.

The first failure was browser CSP. The second failure was Plaid Sandbox credential/request validation. The owner replaced the Vercel Preview `PLAID_SECRET` with the actual Sandbox secret. The next acceptance check is to open Plaid Link and record only a safe provider error code if Plaid rejects it again.

## Exact next action

1. Open the stable URL above in a new tab.
2. Sign in as Dad or Mom.
3. Open Finance Center.
4. Choose **Connect bank · Sandbox**.
5. If Plaid Link opens, use the standard Sandbox institution flow and then test **Sync bank transactions**.
6. If it fails, record the displayed provider code only. Never share secrets or tokens.

## Production boundary

The banking branch is preview-only. Production remains on the existing release. No real bank connection, payment, automatic financial decision, or production promotion is claimed. Supabase Free remains selected; leaked-password protection is a future Pro-plan requirement before real household use.

## Recovery map

- Plaid entry points: `api/plaid/link-token.mjs`, `api/plaid/exchange-token.mjs`, `api/plaid/sync-transactions.mjs`
- Browser transport: `preview/planner-pilot/api.mjs`
- Finance UI: `preview/planner-pilot/finance-workbench.mjs`
- Security policy: `preview/planner-pilot/index.html`
- Chronological record: `docs/DEVELOPMENT_LOG.md`, Entry302
