-- Parent-only Plaid connection metadata. The access token is encrypted by the
-- server before insert; this table is never readable through the browser API.
CREATE TABLE IF NOT EXISTS bb_plaid_connections (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 household_id uuid NOT NULL REFERENCES bb_households(id),
 owner_id uuid NOT NULL REFERENCES auth.users(id),
 item_id text NOT NULL UNIQUE,
 institution_name text,
 access_token_ciphertext text NOT NULL,
 access_token_nonce text NOT NULL,
 access_token_tag text NOT NULL,
 cursor text,
 status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','needs_reauth','disconnected')),
 last_synced_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE bb_plaid_connections ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON bb_plaid_connections FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON bb_plaid_connections TO service_role;
CREATE INDEX IF NOT EXISTS bb_plaid_connections_household ON bb_plaid_connections(household_id,status);
