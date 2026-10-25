# Banking integration — Sandbox stage

The first banking stage uses Plaid Sandbox and read-only `Auth`/`Transactions` products. The Link-token endpoint is parent-only: it verifies the Supabase session and household membership before calling Plaid. Plaid secrets remain server-side and are never returned to the browser.

Current environment variables belong only to Vercel Preview and Development:

- `PLAID_CLIENT_ID`
- `PLAID_SECRET`
- `PLAID_ENV=sandbox`

Production has no Plaid variables. The endpoint is intentionally not presented as a live Finance feature until the secure exchange/storage path, webhook transaction sync, parent review, retention policy and sandbox browser flow are complete. No transfers, payments or automatic Finance approvals are enabled.

Next implementation stages are: exchange the one-time public token server-side, encrypt and store the resulting access token in a parent-only protected table, sync transactions with Plaid's cursor/webhook flow, and expose only reviewed summaries to the Finance workbench. Bank records must remain outside the private Steven OS HTML/JSON recovery exports and outside child contexts.
