-- Flyway migration - versioned SQL, applied automatically by the
-- spring-boot Flyway integration on application startup (never by
-- Hibernate ddl-auto, which is set to "validate" in application.yml).
-- Flyway takes an advisory lock in its schema_history table, so if a
-- rolling deploy briefly runs old and new pods together, only one of them
-- actually executes a given migration - the rest just wait and no-op.
-- See docs/06-kubernetes-advanced.md.
CREATE TABLE orders (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         VARCHAR(64)     NOT NULL,
    status          VARCHAR(32)     NOT NULL DEFAULT 'PENDING',
    total_cents     BIGINT          NOT NULL,
    currency        VARCHAR(8)      NOT NULL DEFAULT 'USD',
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID            NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id      VARCHAR(64)     NOT NULL,
    product_name    VARCHAR(256)    NOT NULL,
    quantity        INT             NOT NULL,
    price_cents     BIGINT          NOT NULL
);

-- Every order list view is "orders for this user, newest first" - this
-- index is what keeps that query fast at 1M-user scale.
CREATE INDEX idx_orders_user_id_created_at ON orders (user_id, created_at DESC);
