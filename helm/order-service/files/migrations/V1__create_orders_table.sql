-- Mirrors services/order-service/src/main/resources/db/migration/V1__create_orders_table.sql
-- exactly. Duplicated into this chart (rather than referenced via a path
-- outside helm/order-service/) because Helm's `.Files.Get` can only read
-- files inside the chart directory. `make sync-migration-configmaps`
-- (see root Makefile) copies the real source of truth here before every
-- `helm package`/`helm upgrade` - if you edit the Flyway migration, run
-- that target so this stays in sync. See docs/10-argocd-gitops.md.
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

CREATE INDEX idx_orders_user_id_created_at ON orders (user_id, created_at DESC);
