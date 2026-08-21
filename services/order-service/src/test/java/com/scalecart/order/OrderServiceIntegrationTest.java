package com.scalecart.order;

import com.scalecart.order.client.ProductServiceClient;
import com.scalecart.order.dto.CreateOrderRequest;
import com.scalecart.order.model.Order;
import com.scalecart.order.service.OrderService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

// Full integration test: real Spring context, H2 in place of Postgres,
// an embedded in-process Kafka broker in place of the real cluster.
// This is what runs in the "test" stage of the CI pipeline before the
// Docker image is even built - see docs/11-github-actions-cicd.md.
@SpringBootTest
@ActiveProfiles("test")
@EmbeddedKafka(partitions = 1, topics = {"order.created", "order.cancelled"})
class OrderServiceIntegrationTest {

    @Autowired
    private OrderService orderService;

    // product-service isn't running in this test - replace the real HTTP
    // client with a mock so stock "reservation" always succeeds. What
    // OrderService does with a real/failing product-service is exercised
    // separately (see ProductServiceClient's own tests would live here in
    // a fuller suite).
    @MockBean
    private ProductServiceClient productServiceClient;

    @Test
    void createOrder_persistsOrderAndComputesTotal() {
        CreateOrderRequest request = new CreateOrderRequest(
                "user-123",
                List.of(new CreateOrderRequest.Item("p1", "Mechanical Keyboard", 2, 5999))
        );

        Order created = orderService.createOrder(request);

        assertThat(created.getId()).isNotNull();
        assertThat(created.getTotalCents()).isEqualTo(11998);
        assertThat(created.getStatus().name()).isEqualTo("PENDING");

        Order fetched = orderService.getOrder(created.getId());
        assertThat(fetched.getItems()).hasSize(1);
    }
}
