import { producer } from "./client";
import { logger } from "../logger";

interface PaymentEventPayload {
  orderId: string;
  userId: string;
  amountCents: number;
}

// notification-service consumes both payment.completed and payment.failed
// to email the customer. order-service could also consume these to flip
// the order's status - out of scope for this demo but wired the same way.
export async function publishPaymentEvent(
  topic: "payment.completed" | "payment.failed",
  payload: PaymentEventPayload
) {
  await producer.send({
    topic,
    messages: [{ key: payload.orderId, value: JSON.stringify(payload) }],
  });
  logger.info({ topic, orderId: payload.orderId }, "payment event published");
}
