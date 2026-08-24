# 08 — Kafka and Event-Driven Communication

## Terminology, mapped to this codebase
- **Broker**: one Kafka node. 3 in the Strimzi cluster (`k8s/kafka/01-kafka-cluster.yaml`); Amazon MSK manages this in the production path.
- **Topic**: a named event stream — `order.created`, `order.cancelled`, `payment.completed`, `payment.failed` (`k8s/kafka/02-topics.yaml`).
- **Partition**: a topic is split into 6 partitions each. Partition count is chosen once, up front — decreasing it later breaks the ordering guarantee for any key already assigned to a partition, so this isn't something to change casually after data exists.
- **Consumer group**: `payment-service-group` and `notification-service-group` are two independent groups both reading `order.created` — Kafka delivers every message to every group (fan-out), but only to one member *within* a group (load-balanced). This is what lets payment-service and notification-service each react to the same event independently, and why adding a third consumer of `order.created` later needs zero changes to order-service. `order-service-group` is that third consumer in practice: order-service reads back `payment.completed`/`payment.failed` (its own events, published by a *different* service) to flip an order's status from `PENDING` to `PAID`/`FAILED` — see `PaymentEventConsumer.java`. Without this, the order row would sit at `PENDING` forever regardless of what actually happened to the payment; it's the piece that closes checkout's async loop end-to-end and what the frontend's order-status page (`services/frontend/src/app/orders/[id]/page.tsx`) actually polls.
- **Offset**: each consumer group tracks, per partition, the last message it successfully processed. This is how a restarted consumer resumes where it left off instead of reprocessing the entire topic.

## At-least-once delivery, and why every consumer here is idempotent
Kafka's durability guarantee is *at-least-once*, not *exactly-once* — a
broker failover before a consumer's offset commit lands can cause the
same message to be redelivered. This project treats that as a given, not
an edge case:
- `payment-service` checks a `processed_events` table by `eventId` before
  charging, and `orderId` is a unique DB constraint on `payments` — so
  even a race between two redelivered copies of the same message can't
  create two payment rows.
- `notification-service` uses a Redis `SET NX` (`app/dedup.py`) as a
  distributed "have I sent this already" lock shared across all its
  replicas.

## Producer configuration (`order-service`)
`acks=all` + `enable.idempotence=true` in `application.yml` means
"published" is a durable, no-duplicate-from-the-producer-retry guarantee
— correctness prioritized over the small latency cost, appropriate for an
event that triggers a real payment charge downstream.

## What's *not* implemented here, and why that's a documented tradeoff
The order write (Postgres) and the event publish (Kafka) in
`OrderService.createOrder` are two separate operations — if the DB commit
succeeds but the Kafka publish then fails, the order exists with no
downstream payment ever triggered. A **transactional outbox** (write the
event to an `outbox` table in the *same* DB transaction as the order,
then a separate poller publishes from that table to Kafka) closes this
gap completely. This project uses the simpler "publish right after commit"
approach deliberately, to keep the codebase readable as a portfolio
piece — but knowing the outbox pattern exists, and being able to explain
when it's worth the extra complexity, is exactly the kind of thing worth
saying out loud in an interview.

## Consumer-lag-based autoscaling (KEDA)
CPU utilization is a poor scaling signal for `payment-service` and
`notification-service`, because their per-message work is I/O-bound (a DB
write, a simulated gateway call) — CPU stays flat even as a backlog of
unprocessed messages grows. `k8s/keda/*-scaledobject.yaml` scales these
two Deployments on **consumer group lag** instead, polling it directly
from Kafka every 15-20s. See docs/06-kubernetes-advanced.md for how KEDA
relates to a normal HPA.
