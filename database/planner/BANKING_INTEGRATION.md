# Banking integration — Sandbox stage

The first banking stage uses Plaid Sandbox and read-only `Auth`/`Transactions` products. The Link-token endpoint is parent-only: it verifies the Supabase session and household membership before calling Plaid. Plaid secrets remain server-side and are never returned to the browser.

Current environment variables belong only to Vercel Preview and Development:

- `PLAID_CLIENT_ID`
- `PLAID_SECRET`
- `PLAID_ENV=sandbox`

Production has no Plaid variables. The endpoint is intentionally not presented as a live Finance feature until the secure exchange/storage path, webhook transaction sync, parent review, retention policy and sandbox browser flow are complete. No transfers, payments or automatic Finance approvals are enabled.

The exchange/storage contract is now implemented in Preview code and the additive `plaid-banking.sql` migration is prepared. It requires `SUPABASE_SERVICE_ROLE_KEY` and a 32-byte base64 `PLAID_TOKEN_ENCRYPTION_KEY` before it will write anything; without those variables it returns `BANKING_NOT_CONFIGURED`. The banking tables and transaction review column are installed in the hosted Supabase database with service-role-only access. Transaction sync and reviewed summaries are wired into the Finance workbench; the remaining production limitation is institution/account balance eligibility. Bank records must remain outside the private Steven OS HTML/JSON recovery exports and outside child contexts.
