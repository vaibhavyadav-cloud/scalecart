package com.scalecart.order;

import com.scalecart.order.client.ProductServiceClient;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

// Goes through the REAL HTTP + Jackson JSON serialization path, unlike
// OrderServiceIntegrationTest (which calls the service layer directly as
// plain Java method calls). This is deliberate: a bug like an infinite
// serialization cycle between Order.items and OrderItem.order, or a
// LazyInitializationException from touching a lazy collection after the
// transaction closed, is INVISIBLE to a test that never serializes the
// entity to JSON - both of those were real bugs caught this way while
// wiring up the frontend's order-detail page. See docs/02's "platform
// contract" - every service having tests is only useful if the tests
// actually exercise the boundary that broke.
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@EmbeddedKafka(partitions = 1, topics = {"order.created", "order.cancelled", "payment.completed", "payment.failed"})
class OrderControllerWebTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private ProductServiceClient productServiceClient;

    @Test
    void createThenGetOrder_roundTripsAsJsonWithoutRecursionOrLazyErrors() throws Exception {
        String createBody = """
                {
                  "userId": "user-web-test",
                  "items": [
                    { "productId": "p1", "productName": "Webcam", "quantity": 2, "priceCents": 4500 }
                  ]
                }
                """;

        String location = mockMvc.perform(post("/orders")
                        .contentType("application/json")
                        .content(createBody))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.totalCents").value(9000))
                .andExpect(jsonPath("$.items[0].productName").value("Webcam"))
                .andReturn().getResponse().getHeader("Location");

        mockMvc.perform(get(location))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].quantity").value(2));
    }
}
