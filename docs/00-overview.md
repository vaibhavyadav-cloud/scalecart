# 00 — What ScaleCart Is and Why It's Built This Way

## The pitch
ScaleCart is a cloud-native, event-driven e-commerce platform: 7 polyglot
services, two database families (relational + NoSQL/cache), Kafka for
async communication, Istio for the service mesh, GitOps delivery via Helm
+ ArgoCD, a GitHub Actions pipeline with SonarQube + Trivy quality/security
gates, and the whole thing provisioned on AWS EKS via Terraform + Ansible.

It exists to prove one thing on a resume: you can design, build, and
operate a system with the same shape as a real production e-commerce
backend — not just write YAML you copied from a tutorial.

## Why e-commerce as the domain
Every reviewer already understands "users browse products, add to cart,
place an order, pay, get notified." That means in an interview you spend
zero time explaining the business and all your time explaining the
**engineering decisions** — which is the actual point of this project.

## Why 7 separate services instead of 1 monolith
Each service in this platform was split out because it has a **different
scaling profile or data shape** than its neighbors, not just "because
microservices are trendy":

| Service | Why it's separate |
|---|---|
| `auth-service` | Security-sensitive (passwords, JWTs) — isolating it limits blast radius if any other service is compromised |
| `product-service` | Read-heavy, bursty (flash sales), benefits from independent horizontal scaling and a flexible document schema |
| `cart-service` | Extremely high write volume (every "add to cart" click) but the data is disposable — doesn't belong in a durable relational store |
| `order-service` | Needs strong consistency/transactions (an order + its line items must commit atomically) |
| `payment-service` | Different compliance boundary (would be the PCI-scoped service in a real system) — isolating it limits audit scope |
| `notification-service` | Pure consumer, no synchronous callers — scales independently based on Kafka lag, not HTTP traffic |

If two of these had the same scaling profile and no compliance reason to
separate, the honest engineering answer would be to keep them as one
service — splitting things that don't need splitting just adds network
hops and operational overhead. See docs/02-microservices-and-tradeoffs.md.

## How to read this repo
1. `services/` — the 7 services, each independently buildable/testable/dockerizable
2. `k8s/`, `helm/`, `argocd/` — how those services actually run in a cluster
3. `.github/workflows/` — how code becomes a running container, safely
4. `terraform/`, `ansible/` — how the cluster and its cloud dependencies come to exist in the first place
5. `docs/` (this folder) — the "why", numbered in the order a real build happens

## Where to start running it
`docker-compose.yml` at the repo root runs the entire platform on a laptop
with one command and no AWS account. Start there — see
docs/17-local-quickstart.md.
