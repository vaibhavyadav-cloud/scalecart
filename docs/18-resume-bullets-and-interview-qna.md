# 18 — Resume Bullets and Interview Q&A

## Resume bullets (pick 3-5, don't paste all of them — tailor to the JD)

- Designed and built **ScaleCart**, a cloud-native e-commerce platform on
  AWS EKS with 7 polyglot microservices (Node.js, Go, Python, Java),
  event-driven communication via Kafka, and a database-per-service
  architecture spanning PostgreSQL, MongoDB, and Redis.
- Implemented an **Istio service mesh** with mutual TLS, weighted
  canary releases, circuit breaking (outlier detection), and
  identity-aware authorization policies — decoupling deploy from release
  for the platform's highest-risk service.
- Built a **GitOps delivery pipeline** with Helm (library-chart pattern
  across 7 charts) and ArgoCD (App-of-Apps, ApplicationSet per
  environment, automated sync with manual production promotion gates).
- Authored a **GitHub Actions CI/CD pipeline** with SonarQube quality
  gates, Trivy vulnerability scanning (blocking on CRITICAL/HIGH CVEs),
  SBOM generation, and OIDC-federated AWS access (no static credentials).
- Provisioned the entire AWS footprint (VPC, EKS, RDS, DocumentDB,
  ElastiCache, MSK, IAM/IRSA) via modular **Terraform**, with **Ansible**
  handling day-1 cluster software bootstrap (Istio, KEDA, Karpenter,
  External Secrets, ArgoCD) — a deliberate IaC/config-management split.
- Designed autoscaling strategy combining CPU-based HPA and **KEDA**
  Kafka-consumer-lag-based scaling, tuned per service's actual bottleneck
  (compute-bound vs. I/O-bound), backed by capacity-planning math for
  ~5,000 req/s sustained load.

## Interview Q&A — the questions this project will actually invite

**"Walk me through the architecture."**
Start from docs/01: one ingress gateway, mesh behind it, 7 services each
with the DB technology that fits their access pattern, Kafka decoupling
the checkout flow's non-blocking steps from the blocking ones. Draw the
diagram from docs/01-architecture.md if you have a whiteboard.

**"Why microservices instead of a monolith here?"**
Answer with the *actual* reasons from docs/02, not "it's the modern way"
— different scaling profiles, a compliance boundary around payment, and
an intentional polyglot choice. Be ready to say the honest cost too:
7 toolchains instead of 1, and that a real team would only pay that cost
if the scaling/compliance reasons were real.

**"How does this handle 1M users?"**
Don't say "Kubernetes auto-scales it." Walk through docs/14: translate
"1M users" into req/s, name the actual bottleneck per layer (compute,
DB connections, event backlog), and the specific lever that addresses
each one. Be ready to admit no load test was actually run — that's more
credible than pretending one was.

**"What happens if a Kafka message is delivered twice?"**
This is your idempotency answer (docs/08): payment-service's
`processed_events` table + a DB-unique `orderId`; notification-service's
Redis `SET NX` dedup lock. Know *why* Kafka can redeliver (at-least-once,
not exactly-once) and be ready to explain what a transactional outbox
would add on top (docs/08 names this as a deliberate simplification).

**"Why didn't you use exactly-once semantics / a transactional outbox?"**
Good question to have a real answer for, not a defensive one: the
DB-write-then-publish gap is a real, acknowledged tradeoff (docs/08),
traded for codebase readability in a portfolio project. Explain what an
outbox table + poller would look like and when the extra complexity earns
its keep (financial reconciliation requirements, an audit needing
provable exactly-once).

**"How do you roll back a bad deploy?"**
`git revert` + a sync (docs/10) — not "redeploy the previous Docker tag
by hand." Mention `selfHeal` catching drift too.

**"How do you know an image is safe to deploy?"**
Trivy blocking the pipeline on CRITICAL/HIGH CVEs, SonarQube's quality
gate, and — the detail that shows depth — the image tag only ever gets
bumped in the GitOps values file *after* both gates pass (docs/11).

**"What would you build next if you had another month?"**
Have 2-3 honest answers ready, pulled from the "deliberately out of
scope" sections in docs/14, docs/15, docs/16: PgBouncer connection
pooling, a transactional outbox, Alertmanager alerting rules, a real load
test. Naming these unprompted is a stronger signal than pretending the
project is "done."
