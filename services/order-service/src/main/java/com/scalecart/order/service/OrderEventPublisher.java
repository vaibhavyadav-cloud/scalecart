package com.scalecart.order.service;

import com.scalecart.order.event.OrderCreatedEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class OrderEventPublisher {

    private final KafkaTemplate<String, Object> kafkaTemplate;

    // Keyed by orderId so every event for the same order lands on the same
    // partition, in order. acks=all + enable.idempotence=true (application.yml)
    // means "published" here is a durable, at-least-once guarantee - the
    // consumer side still has to be idempotent (see notification-service),
    // because at-least-once can still redeliver on consumer-side failures.
    public void publishOrderCreated(OrderCreatedEvent event) {
        kafkaTemplate.send("order.created", event.orderId().toString(), event)
                .whenComplete((result, ex) -> {
                    if (ex != null) {
                        log.error("failed to publish order.created for orderId={}", event.orderId(), ex);
                    } else {
                        log.info("published order.created orderId={} partition={}",
                                event.orderId(), result.getRecordMetadata().partition());
                    }
                });
    }
}
