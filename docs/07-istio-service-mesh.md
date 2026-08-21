# 07 — Istio Service Mesh

## What the mesh does that the application code doesn't have to
Before Istio, "retry a failed call," "encrypt service-to-service traffic,"
and "stop calling a pod that's erroring" would each need to be
implemented independently in 6 different languages. Istio's Envoy
sidecar (auto-injected into every pod via the `istio-injection: enabled`
namespace label — see `k8s/base/00-namespaces.yaml`) implements all three
once, at the infrastructure layer, for every service regardless of
language.

## mTLS (`k8s/istio/00-peer-authentication.yaml`)
`STRICT` mode mesh-wide: every pod-to-pod connection must present a valid
certificate from Istio's own CA, rotated automatically. This is the
"service-to-service traffic is encrypted and authenticated" guarantee a
compliance review typically asks for — implemented as one YAML file
instead of per-service TLS config.

## Traffic routing (`k8s/istio/02-virtual-service.yaml`)
The VirtualService plays the API-gateway role: one external hostname,
path-based routing to each backend. Per-route `timeout`/`retries` also
lives here — notice `/orders` retries only on `reset,connect-failure`,
**not** `5xx`: a 5xx from order-service might mean the order was already
half-created, so blindly retrying could double-create it. Read-only
routes like `/products` retry on `5xx` freely, because a GET is safe to
repeat.

## Circuit breaking (`k8s/istio/03-destination-rules.yaml`)
`outlierDetection` implements the actual circuit-breaker pattern: after N
consecutive 5xx responses, Envoy stops routing to that specific pod for a
cooldown window. `connectionPool` limits are the other half — capping how
much load any single caller can put on one pod, which is what stops a
retry storm from making a struggling pod's problem worse.

## Canary releases (`k8s/istio/04-canary-order-service.yaml`)
Deploying a new version and shifting traffic to it are two separate
actions in this design:
1. ArgoCD deploys `order-service` version `v2` pods alongside the
   existing `v1` pods (both match the Deployment selector, differentiated
   by a `version` label the DestinationRule turns into subsets).
2. This VirtualService controls what **percentage** of traffic each
   subset receives, independent of how many pods of each are running.

Promotion is: watch v2's error rate/latency in Grafana, then edit the
weight split in stages (90/10 → 50/50 → 100/0). Rollback is editing the
weight back to 100/0 favoring v1 — no redeploy, because v1 pods were
never removed. This decoupling of "deploy" from "release" is the actual
point of a service mesh for canaries, versus a plain rolling update where
the two happen together.

## AuthorizationPolicy (`k8s/istio/05-authorization-policies.yaml`)
Identity-aware, fine-grained access control on top of mTLS: e.g. only the
pod running as the `order-service` ServiceAccount may `POST` to
`product-service`'s `/products/*/reserve` endpoint. This is something
`NetworkPolicy` (IP/port only) fundamentally cannot express — it doesn't
know which *service identity* is making a call, only which pod IP.

## Sidecar egress scoping (`k8s/istio/06-sidecar-egress-scoping.yaml`)
Without this, every Envoy proxy holds routing config for every service in
every namespace it can see — a cost that grows with cluster size. Scoping
each service's sidecar to only the hosts it actually calls keeps istiod's
config-push cost roughly constant as the platform grows, which matters
directly for the 1M-request scaling story (docs/14).
