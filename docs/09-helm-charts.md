# 09 — Helm Charts: Library Chart + Per-Service Charts + Umbrella

## The 3-layer structure
```
helm/common/                  ← type: library, not directly installable
helm/<service>/  (×7)         ← depends on ../common, installable standalone
helm/scalecart-umbrella/      ← depends on all 7, installable as one release
```

## Why a library chart instead of copy-pasting templates 7 times
Every service needs the same Deployment/Service/HPA/PDB shape (same
probes contract, same securityContext, same labeling scheme — see
docs/02-microservices-and-tradeoffs.md's "platform contract"). Without a
library chart, fixing a bug in that shape (say, a wrong probe field) means
editing 7 nearly-identical `deployment.yaml` files and hoping none of them
drifted. With `helm/common`, each service's `templates/deployment.yaml`
is one line: `{{ include "common.deployment" . }}` — the shared logic
lives in exactly one place (`helm/common/templates/_helpers.tpl`), and
each service supplies only the values that make it different (image,
resources, probe paths, whether it needs an init container, etc.) via its
own `values.yaml`.

## Why per-service charts AND an umbrella chart
Per-service charts are what let `product-service` deploy independently —
`helm upgrade product-service ./helm/product-service` touches nothing
else. That independence is the entire point of microservices; an umbrella
chart that's the *only* way to deploy would defeat it.

The umbrella chart (`helm/scalecart-umbrella`) exists for the other
half: standing up (or tearing down) the *entire platform* in one action —
a fresh dev namespace, a demo environment, a disaster-recovery restore.
ArgoCD's root Application points at the umbrella chart for exactly this
reason (docs/10-argocd-gitops.md).

## How per-environment values actually get applied
```
helm upgrade scalecart ./helm/scalecart-umbrella \
  -f values.yaml -f values-dev.yaml
```
Helm merges `-f` files left to right, later files winning. `values.yaml`
holds the production-shaped defaults; `values-dev.yaml` /
`values-staging.yaml` override exactly the fields that should differ per
environment (replica counts, autoscaling on/off, image tag, namespace,
IRSA role ARNs) — see the comments at the top of each file in
`helm/scalecart-umbrella/`.

## Where image tags actually come from
Never hand-edited in `values-prod.yaml`. The CI/CD pipeline builds an
image tagged with the git commit SHA, and ArgoCD's Application manifest
(or a `helm upgrade --set <service>.image.tag=<sha>` in the CD step) is
what actually sets the deployed tag — see docs/10 and docs/11.

## Validating charts without a cluster
`helm lint` and `helm template` both work with zero cluster access —
`make helm-lint` at the repo root runs `helm lint` across every chart,
and `helm template ./helm/scalecart-umbrella -f values.yaml -f
values-dev.yaml` renders the exact manifests that would be applied, for
local review.
