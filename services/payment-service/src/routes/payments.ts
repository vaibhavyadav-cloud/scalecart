import { Router } from "express";
import { prisma } from "../prisma";

export const paymentsRouter = Router();

// Read-only lookup - lets the frontend poll "has my payment gone through"
// without needing its own Kafka consumer.
paymentsRouter.get("/payments/:orderId", async (req, res) => {
  const payment = await prisma.payment.findUnique({ where: { orderId: req.params.orderId } });
  if (!payment) return res.status(404).json({ error: "payment_not_found" });
  res.json({ ...payment, amountCents: payment.amountCents.toString() });
});
