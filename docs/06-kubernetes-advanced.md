# 06 — Advanced Kubernetes Features Used Here

## ResourceQuota + LimitRange (`k8s/base/01-resource-quota.yaml`)
ResourceQuota caps total CPU/memory/pod-count for a *namespace*; without
it, one service's HPA scaling to its `maxReplicas` under a traffic spike
could consume every schedulable resource in the cluster and starve every
other service. LimitRange supplies a default request/limit for any
container that omits `resources:` — a missing resources block fails safe
to a small default instead of silently defaulting to unbounded.

## NetworkPolicy (`k8s/base/02-network-policies.yaml`)
Default-deny-all, then explicit allows — the k8s equivalent of a
security-group default-deny posture. This is coarse (IP/port only);
`k8s/istio/05-authorization-policies.yaml` layers finer-grained,
identity-aware rules on top via the mesh (see docs/07).

## External Secrets Operator (`k8s/base/03-external-secrets.yaml`)
Syncs real secret values from AWS Secrets Manager into native `Secret`
objects on a refresh interval, using IRSA (an AWS IAM role bound to a k8s
ServiceAccount — see `terraform/modules/iam`) instead of a static AWS key.
No real credential value is ever committed to git or passed through a CI
log.

## PriorityClass (`k8s/base/04-priority-classes.yaml`)
Three tiers (`scalecart-critical`, `scalecart-standard`,
`scalecart-best-effort`). Under resource pressure, the scheduler
preempts (evicts) lower-priority pods to make room for higher-priority
ones — this is what encodes "a delayed notification email is acceptable;
a dropped payment request is not" as something Kubernetes itself enforces,
not just a runbook note.

## CronJob (`k8s/base/05-cronjob-cart-cleanup.yaml`)
A belt-and-suspenders sweep for any Redis cart key that ends up without a
TTL. `concurrencyPolicy: Forbid` guarantees overlapping runs never happen
even if one run takes longer than the schedule interval.

## Init containers (`auth-service`, `payment-service` Deployments)
Run Prisma's versioned migrations **before** the main container starts,
guaranteeing schema changes land before application code that depends on
them runs — and because an init container runs to completion once per
pod (not continuously), a rolling deploy doesn't race multiple pods
trying to migrate simultaneously the way running migrations inside the
main container's startup code could.

## startupProbe (`order-service` Deployment)
Spring Boot's cold start (Flyway migration + Hibernate metadata + Kafka
producer init) is slower than the other services'. `startupProbe`
suspends liveness/readiness checks until the app finishes booting, so a
slow-but-healthy JVM start is never mistaken for a hung process and killed
mid-boot.

## topologySpreadConstraints
Every stateless service's Deployment spreads its replicas across
availability zones (`topologyKey: topology.kubernetes.io/zone`), so a
single AZ outage degrades capacity instead of fully taking the service
down.

## securityContext (every container)
`runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation:
false`, `capabilities: drop: [ALL]` — a compromised process in any one
container can't write to its own filesystem, can't escalate privileges,
and can't use Linux capabilities it doesn't need. Paired with the
non-root Docker images from docs/04-docker-optimization.md.

## Structured logging → the observability stack
Every service logs structured JSON to stdout (not files) — this is the
k8s-native logging contract: the container runtime captures stdout/stderr,
Fluent Bit (a DaemonSet) tails it cluster-wide and ships it to
CloudWatch/Loki, and because it's JSON, fields like `requestId` (see the
MDC filter in order-service) are queryable instead of needing regex.
