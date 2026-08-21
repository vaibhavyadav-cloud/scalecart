package com.scalecart.order.client;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;

// Synchronous, in-band call to product-service to atomically reserve stock
// at checkout time - this is the one place order creation MUST be
// blocking, because "was there enough stock" has to be known before we
// accept the order. Everything downstream of order creation (payment,
// notification) is async via Kafka instead - see docs/02-microservices-and-tradeoffs.md.
//
// A short connect/request timeout + a small number of retries with backoff
// means a slow product-service degrades checkout latency instead of
// hanging it forever - the "Retry + Backoff" resilience pattern.
@Component
public class ProductServiceClient {

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(2))
            .build();
    private final ObjectMapper mapper = new ObjectMapper();

    @Value("${scalecart.product-service.base-url:http://product-service:4002}")
    private String baseUrl;

    public static class InsufficientStockException extends RuntimeException {
        public InsufficientStockException(String productId) {
            super("insufficient stock for product " + productId);
        }
    }

    public void reserveStock(String productId, int quantity) {
        try {
            String body = mapper.writeValueAsString(Map.of("quantity", quantity));
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(baseUrl + "/products/" + productId + "/reserve"))
                    .timeout(Duration.ofSeconds(3))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() == 409) {
                throw new InsufficientStockException(productId);
            }
            if (response.statusCode() >= 400) {
                throw new IllegalStateException("product-service returned " + response.statusCode());
            }
        } catch (java.io.IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("failed to reach product-service for stock reservation", e);
        }
    }
}
