-- Local dev runs ONE Postgres container with three logical databases to
-- keep laptop resource usage low, while still enforcing "no service reads
-- another service's tables" at the connection-string level (each service
-- only ever gets credentials for its own database). In terraform/ (real
-- AWS), this becomes three genuinely separate RDS instances - see
-- terraform/modules/rds-postgres and docs/03-databases-per-service.md.
CREATE DATABASE scalecart_auth;
CREATE DATABASE scalecart_orders;
CREATE DATABASE scalecart_payments;

\c scalecart_auth
CREATE EXTENSION IF NOT EXISTS pgcrypto;

\c scalecart_orders
CREATE EXTENSION IF NOT EXISTS pgcrypto;

\c scalecart_payments
CREATE EXTENSION IF NOT EXISTS pgcrypto;
