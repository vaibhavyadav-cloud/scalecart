# 01 — Architecture Overview

## Request flow (synchronous path)
```
Browser
  │
  ▼
CloudFront (CDN, static frontend assets from S3)         ← prod only
  │
  ▼
Istio Ingress Gateway  (mTLS terminates here from outside; enforced
  │                      mesh-wide from here on in)
  ▼
┌─────────────────────────────────────────────────────────────┐
│ Istio service mesh (namespace: scalecart-prod)               │
│                                                                │
│  auth-service      product-service     cart-service           │
│  (Node/Express)    (Go/Gin)            (Python/FastAPI)        │
│  → PostgreSQL       → MongoDB           → Redis                │
│                                                                │
│  order-service  ───publish───▶  Kafka  ◀───consume─── payment │
│  (Java/Spring)                  topics        service          │
│  → PostgreSQL                              (Node) → PostgreSQL │
│                                                  │              │
│                                            publish│             │
│                                                  ▼              │
│                                       notification-service      │
│                                       (Python) → Redis (dedup)  │
└─────────────────────────────────────────────────────────────┘
```

## Why synchronous vs asynchronous, per call
- **Frontend → auth/product/cart**: synchronous REST. The user is waiting
  on screen for this response — there's no reason to add a queue in the
  middle.
- **order-service → payment/notification**: asynchronous via Kafka.
  Placing an order should not block on (and fail if) the payment gateway
  or email provider is slow — decoupling means order-service returns
  "order accepted" immediately and the rest happens in the background.
  This is the sync-vs-async tradeoff from the System Design notes this
  project grew out of.

## The two database families
- **Relational (PostgreSQL ×3)**: auth, orders, payments — anywhere a
  transaction must be all-or-nothing (an order and its line items) or
  data has a fixed, well-understood shape (a user record).
- **NoSQL**: MongoDB/DocumentDB for the product catalog (flexible,
  read-heavy documents) and Redis for cart + notification dedup
  (ephemeral, extremely high read/write rate, TTL-based expiry).

Full reasoning: docs/03-databases-per-service.md.

## Database-per-service
No service ever connects to another service's database directly. If
order-service needs product data, it calls product-service's API — it
does not run a JOIN across service boundaries. This is what lets each
service's database be scaled, migrated, or even swapped (Postgres →
something else) without coordinating a release across all 7 services.

## Deployment topology (AWS)
- **EKS** cluster, 3 AZs, managed node groups + Karpenter for burst capacity
- **RDS** (×3, one per relational-data service), **DocumentDB**, **ElastiCache Redis** — all managed, all outside the cluster
- **MSK** (managed Kafka) in the documented prod path; **Strimzi** (in-cluster Kafka operator) for the K8s/Helm demo path that doesn't require a live AWS account
- **ALB** (via AWS Load Balancer Controller) fronting the Istio Ingress Gateway
- **S3 + CloudFront** for the static frontend build

## How this scales toward 1M requests
Short version: horizontal pod autoscaling per service (tuned to that
service's actual bottleneck — CPU for compute-bound services, Kafka
consumer lag for event consumers), read replicas + connection pooling on
the relational databases, Redis absorbing the highest-QPS reads, and
Karpenter adding cluster capacity automatically as pods can't be
scheduled. Full capacity math: docs/14-scaling-to-1m-users.md.
