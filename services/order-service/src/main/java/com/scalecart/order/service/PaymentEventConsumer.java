package com.scalecart.order.service;

import com.scalecart.order.event.PaymentEvent;
import com.scalecart.order.model.Order;
import com.scalecart.order.model.OrderStatus;
import com.scalecart.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

// Closes the loop that OrderEventPublisher opens: order-service publishes
// order.created, payment-service consumes it and eventually publishes
// payment.completed/payment.failed, and THIS is what turns that back
// into a status change on the order row - without it, every order would
// stay PENDING forever regardless of what actually happened to the
// payment. Three independent consumer groups (this one, payment-service's,
// notification-service's) all react to the same topics without knowing
// about each other - see docs/08-kafka-event-driven.md.
@Component
@RequiredArgsConstructor
@Slf4j
public class PaymentEventConsumer {

    private final OrderRepository orderRepository;

    @KafkaListener(topics = "payment.completed", groupId = "order-service-group")
    @Transactional
    public void onPaymentCompleted(PaymentEvent event) {
        updateStatus(event, OrderStatus.PAID);
    }

    @KafkaListener(topics = "payment.failed", groupId = "order-service-group")
    @Transactional
    public void onPaymentFailed(PaymentEvent event) {
        updateStatus(event, OrderStatus.FAILED);
    }

    private void updateStatus(PaymentEvent event, OrderStatus newStatus) {
        UUID orderId;
        try {
            orderId = UUID.fromString(event.orderId());
        } catch (IllegalArgumentException e) {
            log.warn("payment event with unparseable orderId={}", event.orderId());
            return;
        }

        orderRepository.findById(orderId).ifPresentOrElse(order -> {
            // Idempotent by construction: setting PAID on an already-PAID
            // order (a redelivered message - Kafka is at-least-once, see
            // docs/08) is a no-op write, not a bug. We deliberately don't
            // overwrite a terminal FAILED status back to PAID or vice
            // versa out of order - last-write-wins here is acceptable
            // because payment-service's own `payments` table, not this
            // status field, is the source of truth for payment outcome.
            order.setStatus(newStatus);
            orderRepository.save(order);
            log.info("order {} status updated to {}", orderId, newStatus);
        }, () -> log.warn("payment event for unknown orderId={}", orderId));
    }
}
