import { Router } from "express";
import { prisma } from "../prisma";
import { registry } from "../metrics";

export const healthRouter = Router();

healthRouter.get("/health/live", (_req, res) => res.status(200).json({ status: "ok" }));

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
