# 02 — The 7 Services, and the Tradeoffs of Splitting Them

## Service directory
| Service | Port | Stack | Talks to |
|---|---|---|---|
| frontend | 8080 (nginx) | Next.js (static export) | all services, via gateway |
| auth-service | 4001 | Node/Express/TS + Prisma | PostgreSQL |
| product-service | 4002 | Go + Gin | MongoDB |
| cart-service | 4003 | Python FastAPI | Redis |
| order-service | 4004 | Java 21 + Spring Boot 3 | PostgreSQL, Kafka (producer) |
| payment-service | 4005 | Node/Express | PostgreSQL, Kafka (consumer + producer) |
| notification-service | 4006 | Python FastAPI | Redis, Kafka (consumer) |

## Why polyglot at all
Using a different language per service is a deliberate resume signal
("I can operate a platform where teams choose their own stack"), but it's
also a real production pattern: `order-service` uses Spring Boot because
its team needs the JVM's mature transaction/ORM tooling; `product-service`
uses Go because it's a simple, high-throughput read path where Go's low
memory footprint and fast startup matter more than framework richness;
`cart-service`/`notification-service` use Python/FastAPI because they're
thin I/O-bound glue code where developer velocity matters more than raw
throughput.

**The cost of this choice**: 7 different toolchains to patch, secure, and
teach engineers, instead of 1. In a real org this is only worth it when
different teams truly need different stacks — otherwise standardizing on
one language is usually the better call. This project accepts that cost
deliberately, to demonstrate breadth.

## What every service has in common (the platform contract)
Regardless of language, every service implements the same operational
contract, because that's what makes them pluggable into the same k8s
manifests, the same CI pipeline shape, and the same observability stack:

1. `GET /health/live` — liveness probe, never touches a dependency
2. `GET /health/ready` — readiness probe, checks its DB/broker connection
3. `GET /metrics` — Prometheus-format metrics
4. Structured JSON logs to stdout (never plain text — see docs/06-kubernetes-advanced.md)
5. Graceful shutdown on SIGTERM (finish in-flight requests, then exit)
6. A multi-stage Dockerfile producing a minimal, non-root runtime image
7. Config exclusively via environment variables (12-factor) — no config files baked into the image

## Idempotency and event ordering
Kafka only guarantees **at-least-once** delivery — a consumer can see the
same message twice (e.g. after a broker failover before an offset commit
lands). Every consumer in this platform is written to be safe under
redelivery:
- `payment-service` checks a `processed_events` table before charging, and
  `orderId` is a unique key on `payments` — a redelivered `order.created`
  can't double-charge.
- `notification-service` uses a Redis `SET NX` as a distributed dedup
  lock before sending an email.

This is the "duplicate message shouldn't cause harm" idempotency principle
from the System Design notes this project started from.

## Synchronous inter-service calls
`order-service` calls `product-service`'s `/products/:id/reserve`
endpoint synchronously at checkout time to decrement stock atomically
before accepting the order — this one call has to succeed-or-fail before
the order is created, so it stays synchronous REST rather than an event.
Everything *after* the order is accepted (payment, notification) is async.
