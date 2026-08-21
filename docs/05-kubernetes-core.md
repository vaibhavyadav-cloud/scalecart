# 05 — Kubernetes Core Concepts Used Here

Every service in `k8s/base/` follows the same 5-resource pattern:
**ServiceAccount → ConfigMap/Secret → Deployment → Service → HPA + PDB**.

## Deployment
Declares *desired state* ("3 replicas of this container image") and the
Deployment controller continuously reconciles reality toward it — if a
pod crashes, a new one is scheduled automatically; that's the core value
proposition of using k8s instead of `docker run` on a fleet of VMs.

## Service
A stable virtual IP + DNS name (`auth-service.scalecart-prod.svc.cluster.local`)
that load-balances across whichever pods currently match its `selector` —
callers never hardcode a pod IP, which is what makes rolling deploys and
autoscaling invisible to callers.

## Liveness vs. readiness (the distinction from the System Design notes)
- **Liveness** answers "is this process stuck/deadlocked?" → failing it
  gets the pod **restarted**. Must be cheap and dependency-free, or a slow
  database takes down otherwise-healthy pods too.
- **Readiness** answers "can this pod serve traffic right now?" → failing
  it removes the pod from the Service's endpoints **without restarting
  it**. This is what checks the database connection.

Every service in this repo implements both separately (`/health/live` vs
`/health/ready`, or Spring Boot Actuator's `/actuator/health/liveness` vs
`/actuator/health/readiness`) — conflating them is a common mistake that
causes restart storms during a database blip.

## HorizontalPodAutoscaler (HPA)
Watches a metric (CPU/memory utilization here; Kafka lag via KEDA for the
two consumer services — see docs/06) and adjusts `replicas` to hold it
near a target. The `behavior` block on each HPA controls how fast it
scales up vs. down — see the per-service HPA comments in
`k8s/base/1*-*.yaml` for why each service's numbers differ.

## PodDisruptionBudget (PDB)
Caps how many replicas of a service can be down **at the same time** due
to *voluntary* disruption (node drain, cluster upgrade, Karpenter
consolidating nodes) — it does nothing for involuntary disruption (a
crash). Without a PDB, a node drain during a rollout could take an entire
service offline at once if all its replicas happened to land on that node.

## Why Kubernetes Secrets aren't hand-created here
Every Deployment references a Secret by name (`auth-service-secrets`,
etc.) but none of those Secret objects are committed to this repo. They're
populated at runtime by the External Secrets Operator pulling from AWS
Secrets Manager — see `k8s/base/03-external-secrets.yaml` and
docs/15-security-hardening.md.
