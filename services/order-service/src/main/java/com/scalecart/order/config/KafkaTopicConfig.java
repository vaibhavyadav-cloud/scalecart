package com.scalecart.order.config;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class KafkaTopicConfig {

    // 6 partitions = 6 consumer instances of payment-service/notification-service
    // can each own a partition and process in parallel. Partition count is
    // chosen up front because it cannot be safely decreased later without
    // breaking key-based ordering guarantees - see docs/08-kafka-event-driven.md.
    @Bean
    public NewTopic orderCreatedTopic() {
        return org.springframework.kafka.config.TopicBuilder.name("order.created")
                .partitions(6)
                .replicas(3)
                .build();
    }

    @Bean
    public NewTopic orderCancelledTopic() {
        return org.springframework.kafka.config.TopicBuilder.name("order.cancelled")
                .partitions(6)
                .replicas(3)
                .build();
    }
}
