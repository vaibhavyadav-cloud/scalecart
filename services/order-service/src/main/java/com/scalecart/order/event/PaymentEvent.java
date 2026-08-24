package com.scalecart.order.event;

// Mirrors the payload payment-service publishes to payment.completed /
// payment.failed (see services/payment-service/src/kafka/paymentEventProducer.ts).
// Deserialized structurally by field name (spring.json.use.type.headers:
// false in application.yml) since the producer is a different language
// and doesn't send Java type headers.
public record PaymentEvent(
        String orderId,
        String userId,
        long amountCents
) {}
