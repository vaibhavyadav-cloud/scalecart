import { kafka, consumerGroupId } from "./client";
import { prisma } from "../prisma";
import { logger } from "../logger";
import { chargeCard } from "../gateway";
import { publishPaymentEvent } from "./paymentEventProducer";
import { paymentStatusFor, paymentTopicFor } from "../utils/status";

interface OrderCreatedEvent {
  orderId: string;
  userId: string;
  totalCents: number;
  currency: string;
  eventId: string;
}

// Consumes order.created and attempts payment capture. Idempotent by
// design: (1) eventId is checked against processed_events before doing
// any work, and (2) orderId is unique on the payments table, so even a
// race between two redelivered copies of the same message can't create
// two payment rows for one order.
export async function startOrderCreatedConsumer() {
  const consumer = kafka.consumer({ groupId: consumerGroupId });
  await consumer.connect();
  await consumer.subscribe({ topic: "order.created", fromBeginning: false });

  await consumer.run({
    eachMessage: async ({ message }) => {
      if (!message.value) return;
      const event: OrderCreatedEvent = JSON.parse(message.value.toString());

      const alreadyProcessed = await prisma.processedEvent.findUnique({
        where: { eventId: event.eventId },
      });
      if (alreadyProcessed) {
        logger.info({ eventId: event.eventId }, "duplicate event skipped");
        return;
      }

      const { approved } = await chargeCard(event.totalCents);

      await prisma.$transaction(async (tx) => {
        await tx.payment.upsert({
          where: { orderId: event.orderId },
          create: {
            orderId: event.orderId,
            userId: event.userId,
            amountCents: BigInt(event.totalCents),
            currency: event.currency,
            status: paymentStatusFor(approved),
          },
          update: {},
        });
        await tx.processedEvent.create({ data: { eventId: event.eventId } });
      });

      await publishPaymentEvent(paymentTopicFor(approved), {
        orderId: event.orderId,
        userId: event.userId,
        amountCents: event.totalCents,
      });

      logger.info({ orderId: event.orderId, approved }, "payment processed");
    },
  });
}
