# 03 — Database-per-Service: Two Families, Five Instances

## The two families, and why each exists
| Family | Tech | Used by | Why this family |
|---|---|---|---|
| Relational | PostgreSQL | auth, order, payment | Need real transactions (an order + line items commit together), fixed schema, strong consistency |
| NoSQL — document | MongoDB / DocumentDB | product | Read-heavy, variable/nested schema per product category, no cross-document transactions needed |
| NoSQL — key-value | Redis | cart, notification (dedup) | Ephemeral, extremely hot read/write path, TTL-based expiry is a first-class feature, not a workaround |

## Why database-per-service instead of one shared database
A shared database means any service can accidentally depend on another
service's internal table structure, which makes it impossible to change
one service's schema without a cross-team migration. Splitting the
database per service is what actually enforces the "the only way to reach
my data is through my API" rule — without it, "microservices" is really
just one monolith with extra network hops.

**Cost paid for this**: no cross-service JOINs, no single ACID transaction
spanning two services' data (e.g. "decrement product stock" and "create
order row" are two separate calls, not one SQL transaction — see the
`ProductServiceClient` synchronous reservation call in order-service,
and docs/02-microservices-and-tradeoffs.md for why that one call stays
synchronous).

## Local dev vs. production topology
- **docker-compose (local)**: one Postgres *container* hosting three
  separate *databases* (`scalecart_auth`, `scalecart_orders`,
  `scalecart_payments` — see `infra/postgres-init/01-create-databases.sql`),
  one Mongo container, one Redis container. This keeps a laptop's resource
  usage sane while still enforcing "each service only has credentials to
  its own database."
- **Terraform/AWS (production)**: `terraform/modules/rds-postgres` is
  instantiated three times as three genuinely separate RDS instances (so
  auth, orders, and payments can be scaled, patched, and failed over
  independently), plus one DocumentDB cluster and one ElastiCache Redis
  cluster.

## Indexing decisions actually made in this codebase
- `orders(user_id, created_at DESC)` — every "my orders" page query is
  "orders for this user, newest first"; without this compound index that
  query becomes a full table scan once the table has millions of rows.
- MongoDB `products` collection is queried by `category` in the catalog
  browse page — a single-field index on `category` is the equivalent here.
- Redis needs no indexes by definition — the key *is* the index
  (`cart:{user_id}`, `notif:dedup:{topic}:{id}`).

## Connection pooling at scale
Each service pod holds a small local pool (e.g. HikariCP
`maximum-pool-size: 10` in order-service), not a large one — because the
real constraint is `RDS max_connections`, shared across every pod of every
service that talks to that database. At high replica counts, a per-pod
pool that's too large exhausts the database before it exhausts CPU. See
docs/14-scaling-to-1m-users.md for the actual math and where PgBouncer
fits in.
