import pino from "pino";

// Structured JSON logging - required so log collectors running in the cluster
// (Fluent Bit / CloudWatch) can parse fields instead of grepping plain text.
// See docs/06-kubernetes-advanced.md for how this plugs into the logging stack.
export const logger = pino({
  level: process.env.LOG_LEVEL || "info",
  formatters: {
    level: (label) => ({ level: label }),
  },
  base: {
    service: "auth-service",
  },
  timestamp: pino.stdTimeFunctions.isoTime,
});
