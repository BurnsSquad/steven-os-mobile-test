-- Reviewed transaction summaries only. Raw provider payloads and credentials
-- are deliberately excluded from this table and from all browser exports.
CREATE TABLE IF NOT EXISTS bb_plaid_transactions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 connection_id uuid NOT NULL REFERENCES bb_plaid_connections(id) ON DELETE CASCADE,
 household_id uuid NOT NULL REFERENCES bb_planner_households(id),
 owner_id uuid NOT NULL REFERENCES auth.users(id),
 transaction_id text NOT NULL,
 account_id text NOT NULL,
 merchant_name text,
 name text NOT NULL,
 amount_cents bigint NOT NULL,
 currency_code text,
 posted_on date,
 pending boolean NOT NULL DEFAULT false,
 category text,
 is_removed boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(connection_id,transaction_id)
);
ALTER TABLE bb_plaid_transactions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON bb_plaid_transactions FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON bb_plaid_transactions TO service_role;
CREATE INDEX IF NOT EXISTS bb_plaid_transactions_household_date ON bb_plaid_transactions(household_id,posted_on DESC);
