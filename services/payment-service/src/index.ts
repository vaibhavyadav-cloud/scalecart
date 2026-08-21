import express from "express";
import helmet from "helmet";
import pinoHttp from "pino-http";
import { logger } from "./logger";
import { healthRouter } from "./routes/health";
import { paymentsRouter } from "./routes/payments";
import { producer } from "./kafka/client";
import { startOrderCreatedConsumer } from "./kafka/orderCreatedConsumer";

const app = express();
const PORT = process.env.PORT || 4005;

app.use(helmet());
app.use(express.json());
app.use(pinoHttp({ logger }));
app.use(healthRouter);
app.use(paymentsRouter);

async function main() {
  await producer.connect();
  await startOrderCreatedConsumer();

  const server = app.listen(PORT, () => {
    logger.info(`payment-service listening on port ${PORT}`);
  });

  process.on("SIGTERM", () => {
    logger.info("SIGTERM received, shutting down gracefully");
    server.close(async () => {
      await producer.disconnect();
      process.exit(0);
    });
  });
}

main().catch((err) => {
  logger.error({ err }, "fatal startup error");
  process.exit(1);
});
