import { Kafka, logLevel } from "kafkajs";

const brokers = (process.env.KAFKA_BOOTSTRAP_SERVERS || "localhost:9092").split(",");

export const kafka = new Kafka({
  clientId: "payment-service",
  brokers,
  logLevel: logLevel.WARN,
  retry: {
    // Exponential backoff on broker connection errors, not an immediate
    // hot-loop retry - see "Retry + Backoff" in your System Design notes.
    initialRetryTime: 300,
    retries: 8,
  },
});

export const producer = kafka.producer({ idempotent: true });

// A dedicated consumer group id means this service's replicas share the
// topic's partitions (each partition consumed by exactly one pod at a
// time) instead of every pod re-reading every message.
export const consumerGroupId = "payment-service-group";
