# 17 — Local Quickstart

## Fastest path: docker-compose (no AWS account, no Kubernetes)
```bash
cp .env.example .env
make up          # docker compose up -d --build
make logs        # follow every service's logs
```
This runs all 7 services + Postgres + MongoDB + Redis + Kafka (KRaft
mode) + a Kafka UI, wired exactly like production (same env var names,
same topic names, same two DB families) — see docs/00-overview.md and
`docker-compose.yml`'s inline comments.

Once it's up:
- Frontend: http://localhost:3000
- Kafka UI (inspect topics/consumer groups/lag): http://localhost:8090
- Each service directly: http://localhost:400{1..6}/health/live

Try the actual flow:
```bash
# Register + log in
curl -X POST localhost:4001/auth/register -H 'Content-Type: application/json' \
  -d '{"email":"a@b.com","password":"password1","fullName":"Ada"}'
curl -X POST localhost:4001/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"a@b.com","password":"password1"}'

# Add a product, then place an order for it
curl -X POST localhost:4002/products -H 'Content-Type: application/json' \
  -d '{"sku":"KB-1","name":"Keyboard","priceCents":5999,"currency":"USD","category":"electronics","stockQty":10}'
curl -X POST localhost:4004/orders -H 'Content-Type: application/json' \
  -d '{"userId":"user-1","items":[{"productId":"<id-from-above>","productName":"Keyboard","quantity":1,"priceCents":5999}]}'
```
Watch `docker compose logs -f payment-service notification-service` —
you'll see the order.created event get consumed, a simulated payment
processed, and a simulated notification logged, entirely asynchronously.

## Running each service's own tests
```bash
make test-all     # every service's own test suite, no shared DB/Kafka needed
make lint-all
```

## Validating the infra layers without a cluster or cloud account
```bash
make helm-lint      # helm lint across every chart
make tf-validate     # terraform validate, no AWS credentials needed
```

## Full path: a real (or local kind/minikube) Kubernetes cluster
1. `terraform apply` in `terraform/envs/dev` (or point `kubectl` at any
   existing cluster if you're not using AWS — everything after this step
   is cluster-agnostic).
2. `ansible-playbook playbooks/00-bootstrap-tools.yml`
3. `ansible-playbook playbooks/01-install-cluster-addons.yml -e "..."`
   (variables from `terraform output`, see docs/13-ansible.md)
4. `ansible-playbook playbooks/02-configure-argocd.yml`
5. From here on, everything is GitOps — push to `main` and ArgoCD deploys
   dev/staging automatically; `argocd app sync scalecart-prod` promotes to
   prod after review (docs/10-argocd-gitops.md).

## Where to look when something doesn't come up
- `kubectl get pods -n scalecart-dev` — is a pod stuck in
  `CrashLoopBackOff`? Check `kubectl logs`, then check whether its
  `initContainer` (DB migration) succeeded first.
- `kubectl get applications -n argocd` — ArgoCD's own view of sync status
  per environment.
- `istioctl analyze -n scalecart-dev` — catches common mesh
  misconfigurations (a Gateway with no matching VirtualService, etc).
