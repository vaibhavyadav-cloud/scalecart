import { Router } from "express";
import { prisma } from "../prisma";
import { registry } from "../metrics";

export const healthRouter = Router();

// Liveness: "is the process alive?" - k8s restarts the pod if this fails.
// Must NOT depend on the database, or a slow DB takes down healthy pods too.
healthRouter.get("/health/live", (_req, res) => {
  res.status(200).json({ status: "ok" });
});

// Readiness: "can this pod serve traffic right now?" - k8s pulls the pod out
// of the Service endpoints list if this fails, without restarting it.
// This DOES check the DB, because a pod that can't reach Postgres can't
// actually serve /auth/login requests.
healthRouter.get("/health/ready", async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.status(200).json({ status: "ready" });
  } catch {
    res.status(503).json({ status: "not_ready" });
  }
});

healthRouter.get("/metrics", async (_req, res) => {
  res.setHeader("Content-Type", registry.contentType);
  res.send(await registry.metrics());
});
