# 04 — Docker: Multi-Stage Builds and Image Optimization

Every service's `Dockerfile` follows the same shape, adapted per language:

## The pattern
1. **Builder stage** — full toolchain (compilers, package managers), builds
   the artifact (compiled JAR, Go binary, TS→JS, npm install)
2. **(Node services only) deps stage** — installs *production-only*
   dependencies separately from the builder's dev+prod install, so
   dev-only packages (TypeScript, ts-node-dev, jest) never reach the final
   image
3. **Runtime stage** — starts from a minimal base image, copies in only
   the built artifact + production deps, runs as a **non-root user**,
   exposes exactly one port, defines a `HEALTHCHECK`

## Base image choices, and why
| Service | Runtime base | Why |
|---|---|---|
| auth/payment-service | `node:20-alpine` | Alpine keeps the image small; a distroless Node image isn't practical because `npm`/native module resolution still expects a minimal shell in most setups |
| product-service | `gcr.io/distroless/static-debian12:nonroot` | Go compiles to a single static binary with no runtime deps at all — distroless (no shell, no package manager) is the smallest possible attack surface, and Trivy scans of this image typically come back with near-zero CVEs |
| order-service | `eclipse-temurin:21-jre-alpine` | JRE (not full JDK) — the built JAR doesn't need a compiler at runtime |
| cart/notification-service | `python:3.12-slim` | A Python venv copied from the builder stage avoids installing build tools (gcc, headers) into the final image |
| frontend | `nginxinc/nginx-unprivileged:1.27-alpine` | Serves the static `next export` output; the unprivileged variant runs nginx as UID 101 by default, not root |

## Why non-root matters here specifically
The Kubernetes `securityContext` in `k8s/base/*-deployment.yaml` sets
`runAsNonRoot: true` and will **refuse to start the pod** if the image's
default user is root. Building non-root into the image itself (rather
than only setting `runAsUser` at the k8s layer) means the image is safe
even if someone runs it with plain `docker run` outside the cluster.

## What Trivy actually catches here
The CI pipeline (`.github/workflows/reusable-build-scan-push.yml`) runs
Trivy against the built image, not the source code — it's scanning the
OS packages and language dependencies baked into the final layer. This is
why the runtime stage only copies compiled artifacts and prod
dependencies: every package in the builder stage that *doesn't* make it
into the runtime stage is one fewer CVE Trivy has to report and one fewer
attack surface. See docs/11-github-actions-cicd.md.

## HEALTHCHECK vs. Kubernetes probes
Every Dockerfile also defines a `HEALTHCHECK` instruction hitting
`/health/live`. This is redundant with the k8s liveness probe defined in
the Deployment manifest — it exists so `docker compose ps` and plain
`docker run` (i.e., local dev, no k8s) still show accurate container
health.
