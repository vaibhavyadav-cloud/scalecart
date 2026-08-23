# 14 — Scaling Toward 1M Users: the Actual Capacity Story

This is the doc to read before an interview question like "how does this
handle a million users." The honest answer is never one silver bullet —
it's a stack of decisions, each addressing a specific bottleneck, made
throughout this repo. This doc collects them in one place and does the
back-of-envelope math.

## Translate "1M users" into a request rate first
"1M users" isn't a load number by itself — what matters is concurrent
request rate. A common, defensible assumption for an e-commerce platform:
1M *registered* users, ~5% concurrently active during a peak hour, each
generating roughly 1 request every 10 seconds while active (browsing,
adding to cart, checking order status):

```
1,000,000 users × 5% concurrent = 50,000 concurrent users
50,000 users ÷ 10s per request  = ~5,000 requests/second at peak
```

That's the number every capacity decision below is actually sized against
— not "1 million," but "~5k req/s sustained, with headroom for a 3-5x
flash-sale-style spike (~15-25k req/s)."

## Where that traffic actually lands (it's not evenly spread)
Catalog browsing (`product-service`) and cart operations (`cart-service`)
dominate request *count* — every page view hits them. Checkout
(`order-service`, `payment-service`) is a much smaller fraction of
requests but each one is more expensive (a DB write + a synchronous stock
reservation call + a Kafka publish). This is exactly why the HPA
`maxReplicas` ceilings differ so much per service in `k8s/base/1*-*.yaml`:
`product-service` goes up to 40 replicas, `order-service` only to 15 —
sizing every service identically would either under-provision the read
path or waste money over-provisioning checkout.

## The actual levers, mapped to where they live in this repo
| Bottleneck | Lever | Where |
|---|---|---|
| Compute capacity per service | HPA (CPU/memory) tuned per service's real profile | `k8s/base/1*-*.yaml` |
| Compute for I/O-bound Kafka consumers | KEDA scaling on consumer lag, not CPU | `k8s/keda/*.yaml`, docs/08 |
| Cluster-level node capacity | Baseline managed node group (floor) + Karpenter (burst, launches in seconds) | `terraform/modules/eks`, `ansible/roles/karpenter` |
| Database connection exhaustion | Small per-pod connection pools (HikariCP `max-pool-size: 10`) sized against RDS `max_connections`, not against the pod's own throughput | `services/order-service/.../application.yml`, docs/03 |
| Read-heavy DB load | Read replicas where proven necessary (orders, not auth/payments) | `terraform/envs/prod/main.tf` |
| Highest-QPS reads | Redis absorbs cart reads entirely; product catalog reads hit MongoDB indexes, not Postgres | docs/03 |
| Static asset delivery | CloudFront CDN in front of S3 - these requests never reach a pod at all | `terraform/modules/s3-cloudfront` |
| Checkout correctness under concurrency | Atomic `$inc`-with-filter stock reservation (no distributed lock needed) | `product-service/internal/handlers/product.go` |
| Event backlog under a sudden order spike | Kafka partitioning (6 partitions per topic = 6-way parallel consumption) | docs/08 |
| A single failing pod dragging down callers | Istio circuit breaking (`outlierDetection`) | `k8s/istio/03-destination-rules.yaml`, docs/07 |
| A single AZ outage | `topologySpreadConstraints` across 3 AZs, Multi-AZ RDS | `k8s/base/*.yaml`, `terraform/modules/rds-postgres` |

## The connection-pool math specifically (a commonly-missed bottleneck)
This is the one engineers most often get wrong when scaling out: adding
pods does NOT scale a database's connection capacity — it can silently
*exhaust* it. Example, `order-service`:
```
HikariCP maximum-pool-size:     10 connections/pod
order-service HPA maxReplicas:  15 pods
Worst case connection demand:   150 connections

RDS db.t4g.medium max_connections (default): ~450

150 < 450 → safe at max scale, for THIS service alone.
```
But `order-service` isn't the only thing connecting to `orders-db` — a
migration Job, a monitoring exporter, an ad-hoc `psql` session during an
incident all count too. This is exactly why production setups put
PgBouncer (transaction pooling mode) in front of RDS: PgBouncer holds a
much smaller number of *real* Postgres connections and multiplexes many
more logical client connections onto them, decoupling "how many pods do I
have" from "how many real DB connections exist." This project's
`docker-compose.yml`/dev Helm values connect directly to Postgres for
simplicity; a note in `terraform/modules/rds-postgres` and this doc is
the honest flag that PgBouncer is the next thing to add before this
platform is asked to genuinely sustain peak load in a real account.

## What's deliberately NOT built here, and why that's fine to say
- No CDN cache invalidation strategy beyond CloudFront defaults — fine
  for a portfolio project, a real launch would tune cache TTLs per asset
  type.
- No multi-region — everything above assumes one AWS region. Multi-region
  active-active would need a strategy for the two Postgres write-masters
  problem (not solved by "just add Terraform"), which is a legitimately
  hard, separate project.
- No load test actually run against this stack — the numbers above are
  sizing math, not a k6/Locust result. Saying that plainly in an
  interview is more credible than implying a benchmark exists that
  doesn't.
