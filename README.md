# ScaleCart

A cloud-native, event-driven e-commerce platform — built as a full
DevOps portfolio project. Polyglot microservices, two database families,
Kafka, an Istio service mesh, GitOps delivery via Helm + ArgoCD, a
GitHub Actions CI/CD pipeline with SonarQube + Trivy gates, and the full
AWS footprint provisioned via Terraform + Ansible.

**Every design decision is documented, not just implemented** — see
[`docs/`](docs/00-overview.md) for the numbered "what and why" behind
every layer. Start there; this README is just the map.

## Architecture at a glance

```
Browser → CloudFront (CDN) → Istio Ingress Gateway (mTLS from here on)
                                       │
        ┌──────────────────────────────┼──────────────────────────────┐
        │                    Istio service mesh                        │
        │                                                                │
        │  frontend        auth-service      product-service            │
        │  (Next.js)       (Node/Express)    (Go/Gin)                   │
        │                  → PostgreSQL      → MongoDB                  │
        │                                                                │
        │  cart-service    order-service ──publish──▶ Kafka             │
        │  (Python/FastAPI) (Java/Spring)              │  ▲              │
        │  → Redis          → PostgreSQL      consume──┘  └──consume    │
        │                                       │              │        │
        │                              payment-service   notification-  │
        │                              (Node) → PostgreSQL  service      │
        │                                                  (Python)      │
        │                                                  → Redis       │
        └────────────────────────────────────────────────────────────┘
```

Full diagram + reasoning: [`docs/01-architecture.md`](docs/01-architecture.md).

## Repository layout

| Path | What it is |
|---|---|
| `services/` | The 7 services — real, runnable code, own Dockerfile + tests each |
| `docker-compose.yml` | Full local stack, one command, no cloud account needed |
| `k8s/base/` | Namespaces, quotas, network policies, per-service Deployment/Service/HPA/PDB |
| `k8s/istio/` | Service mesh: mTLS, routing, circuit breaking, canary, authorization |
| `k8s/keda/`, `k8s/kafka/` | Kafka-lag autoscaling; in-cluster Kafka (Strimzi) for the demo path |
| `helm/` | Library chart + one chart per service + an umbrella chart |
| `argocd/` | GitOps: App-of-Apps, ApplicationSet per environment, PreSync hooks |
| `.github/workflows/` | CI/CD: lint → test → SonarQube → Trivy → SBOM → push → GitOps tag bump |
| `terraform/` | AWS infra: network, EKS, RDS ×3, DocumentDB, ElastiCache, MSK, ECR, IAM |
| `ansible/` | Day-1 cluster software bootstrap (Istio, KEDA, Karpenter, ArgoCD, ...) |
| `docs/` | Numbered teaching notes — the "why" behind everything above |

## Quickstart

```bash
cp .env.example .env
make up      # docker compose up -d --build - the whole platform, locally
make logs
```

Frontend: http://localhost:3000 · Kafka UI: http://localhost:8090

Full walkthrough (a real register → order → async payment flow) and the
path to a real Kubernetes cluster: [`docs/17-local-quickstart.md`](docs/17-local-quickstart.md).

## Validate the infra layers without touching a cloud account

```bash
make helm-lint      # helm lint across all 9 charts
make tf-validate    # terraform validate, no AWS credentials needed
make test-all       # every service's own test suite
```

## Documentation index

00. [Overview & why this project exists](docs/00-overview.md)
01. [Architecture](docs/01-architecture.md)
02. [Microservices & tradeoffs](docs/02-microservices-and-tradeoffs.md)
03. [Databases per service](docs/03-databases-per-service.md)
04. [Docker optimization](docs/04-docker-optimization.md)
05. [Kubernetes core concepts](docs/05-kubernetes-core.md)
06. [Kubernetes advanced features](docs/06-kubernetes-advanced.md)
07. [Istio service mesh](docs/07-istio-service-mesh.md)
08. [Kafka & event-driven design](docs/08-kafka-event-driven.md)
09. [Helm charts](docs/09-helm-charts.md)
10. [ArgoCD & GitOps](docs/10-argocd-gitops.md)
11. [GitHub Actions CI/CD](docs/11-github-actions-cicd.md)
12. [Terraform IaC](docs/12-terraform-iac.md)
13. [Ansible](docs/13-ansible.md)
14. [Scaling to 1M users](docs/14-scaling-to-1m-users.md)
15. [Security hardening](docs/15-security-hardening.md)
16. [Observability](docs/16-observability.md)
17. [Local quickstart](docs/17-local-quickstart.md)
18. [Resume bullets & interview Q&A](docs/18-resume-bullets-and-interview-qna.md)

## Tech stack

**Frontend:** Next.js (TypeScript), static export, Nginx
**Backend:** Node.js/Express, Go/Gin, Python/FastAPI, Java/Spring Boot 3
**Databases:** PostgreSQL ×3 (auth/orders/payments), MongoDB/DocumentDB (catalog), Redis (cart/dedup)
**Messaging:** Kafka (Strimzi in-cluster demo path / Amazon MSK production path)
**Mesh:** Istio (mTLS, canary, circuit breaking, authorization policies)
**Orchestration:** Kubernetes (EKS), Helm, ArgoCD, KEDA, Karpenter
**CI/CD:** GitHub Actions, SonarQube, Trivy, Syft (SBOM)
**IaC:** Terraform, Ansible
