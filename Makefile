.PHONY: up down build logs ps test-all lint-all helm-lint k8s-validate tf-validate ansible-check sync-migration-configmaps clean

## ---- Local dev (docker-compose) ----
up:
	docker compose up -d --build

down:
	docker compose down -v

build:
	docker compose build

logs:
	docker compose logs -f --tail=100

ps:
	docker compose ps

## ---- Quality gates you can run before pushing ----
test-all:
	cd services/auth-service && npm test
	cd services/payment-service && npm test
	cd services/frontend && npm test
	cd services/cart-service && python -m pytest
	cd services/notification-service && python -m pytest
	cd services/product-service && go test ./...
	cd services/order-service && mvn -q test

lint-all:
	cd services/auth-service && npm run lint
	cd services/payment-service && npm run lint
	cd services/frontend && npm run lint
	cd services/cart-service && python -m flake8 app
	cd services/notification-service && python -m flake8 app
	cd services/product-service && go vet ./...

## ---- Infra validation (no live cluster/cloud account needed) ----
helm-lint:
	for c in helm/common helm/auth-service helm/product-service helm/cart-service helm/order-service helm/payment-service helm/notification-service helm/frontend helm/scalecart-umbrella; do \
		helm lint $$c || exit 1; \
	done

k8s-validate:
	kubectl apply --dry-run=client -f k8s/base -R

tf-validate:
	cd terraform/envs/dev && terraform init -backend=false && terraform validate

ansible-check:
	ansible-lint ansible/playbooks

## Keeps helm/order-service/files/migrations/ in sync with the real Flyway
## source of truth in services/order-service/ - run this after editing a
## migration, before `helm package`/`helm upgrade`. See docs/10-argocd-gitops.md.
sync-migration-configmaps:
	cp services/order-service/src/main/resources/db/migration/*.sql helm/order-service/files/migrations/

clean:
	docker compose down -v --remove-orphans
	docker system prune -f
