# 16 — Observability: Metrics, Logs, Traces

The three pillars, and where each one actually comes from in this repo —
none of them required touching the 7 services' business logic, because
the instrumentation lives at the platform layer.

## Metrics
Every service exposes `/metrics` in Prometheus text format (`prom-client`
for Node, `client_golang` for Go, `prometheus-fastapi-instrumentator` for
Python, Micrometer + `micrometer-registry-prometheus` for Spring Boot),
and every Deployment carries `prometheus.io/scrape: "true"` annotations
(`k8s/base/1*-*.yaml`). `kube-prometheus-stack`
(`ansible/roles/observability`) scrapes all of them on a 15s interval
with zero per-service configuration needed — Prometheus auto-discovers
scrape targets from those annotations.

**What you'd actually watch in Grafana for this platform**: per-service
p50/p99 latency and error rate (from the `http_request_duration_seconds`
histogram every service emits), HPA current-vs-desired replica count,
and Kafka consumer lag per topic (the same metric KEDA scales on — see
docs/08 and docs/14).

## Logs
Every service logs structured JSON to stdout — never to a file, never
plain text (docs/06's rationale). The container runtime captures
stdout/stderr; a Fluent Bit DaemonSet (not included as a separate
Ansible role here, but the natural next add-on alongside
`kube-prometheus-stack`) tails every pod's logs cluster-wide and ships
them to CloudWatch Logs or a Loki instance. Because logs are JSON,
fields like `requestId` (set via the MDC filter in `order-service`, or
the equivalent request-scoped context in the other services) are
directly queryable — "show me every log line for this one request across
every service it touched" is a field filter, not a regex.

## Traces
Istio's Envoy sidecar automatically emits a span for every request that
crosses the mesh — no application code changes needed, because the
instrumentation happens at the proxy, not in-process.
`ansible/roles/observability` points that tracing config at a Jaeger
backend. This is genuinely useful for exactly the kind of request this
platform has: `order-service`'s synchronous call to `product-service`
(docs/02) shows up as a parent-child span pair in Jaeger, so a slow
checkout can be diagnosed as "the stock-reservation call was slow" vs.
"the order write itself was slow" without adding any tracing code to
either service.

## What ties it together during an actual incident
1. Grafana shows `order-service`'s error rate spiking.
2. The Istio dashboard (part of `kube-prometheus-stack`'s Istio add-on
   dashboards) shows `product-service` is the destination returning 5xxs.
3. `outlierDetection` (`k8s/istio/03-destination-rules.yaml`) has likely
   already ejected the misbehaving `product-service` pod from the load
   balancing pool automatically — the circuit breaker in docs/07 buys
   time before a human even opens Grafana.
4. Jaeger confirms which specific downstream call is slow; Loki/CloudWatch
   Logs (filtered by `requestId`) shows the actual error from that pod's
   logs.

## Deliberately out of scope here
Alertmanager routing rules (PagerDuty/Slack integration), SLO burn-rate
alerts, and a curated set of Grafana dashboards beyond the chart's
defaults — all reasonable next steps, left out to keep this project's
scope centered on the CI/CD, mesh, and IaC layers it's meant to
demonstrate.
