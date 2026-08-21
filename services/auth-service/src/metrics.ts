import client from "prom-client";

// Every service exposes /metrics in Prometheus text format.
// Prometheus (deployed via the kube-prometheus-stack Helm chart, see
// docs/16-observability.md) scrapes this on a 15s interval per pod.
export const registry = new client.Registry();
client.collectDefaultMetrics({ register: registry });

export const httpRequestDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2, 5],
});
registry.registerMetric(httpRequestDuration);
