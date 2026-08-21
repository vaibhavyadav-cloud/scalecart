import client from "prom-client";

export const registry = new client.Registry();
client.collectDefaultMetrics({ register: registry });

export const paymentsProcessed = new client.Counter({
  name: "payments_processed_total",
  help: "Total payments processed, labeled by outcome",
  labelNames: ["status"],
});
registry.registerMetric(paymentsProcessed);
