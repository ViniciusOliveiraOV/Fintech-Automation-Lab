CREATE TABLE IF NOT EXISTS payments (
    id BIGSERIAL PRIMARY KEY,
    stripe_session_id TEXT NOT NULL UNIQUE,
    customer_email TEXT,
    amount_total NUMERIC(12, 2) NOT NULL,
    currency VARCHAR(10) NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments (created_at);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments (status);
