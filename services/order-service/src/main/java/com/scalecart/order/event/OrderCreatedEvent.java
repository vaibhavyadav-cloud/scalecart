package com.scalecart.order.event;

import java.util.List;
import java.util.UUID;

// Event payload published to the "order.created" Kafka topic.
// payment-service and notification-service both consume this topic
// independently (fan-out via consumer groups) - order-service does not
// know or care who's listening, which is the whole point of decoupling
// through a broker instead of order-service calling them directly.
public record OrderCreatedEvent(
        UUID orderId,
        String userId,
        long totalCents,
        String currency,
        List<Item> items,
        String eventId // used by consumers for idempotent processing (dedupe on this key)
) {
    public record Item(String productId, String productName, int quantity, long priceCents) {}
}
