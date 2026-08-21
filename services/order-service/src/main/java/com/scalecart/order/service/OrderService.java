package com.scalecart.order.service;

import com.scalecart.order.client.ProductServiceClient;
import com.scalecart.order.dto.CreateOrderRequest;
import com.scalecart.order.event.OrderCreatedEvent;
import com.scalecart.order.model.Order;
import com.scalecart.order.model.OrderItem;
import com.scalecart.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final OrderEventPublisher eventPublisher;
    private final ProductServiceClient productServiceClient;

    // The order write + the Kafka publish happen in the same method, but the
    // publish is fire-and-forget async (see OrderEventPublisher) so it does
    // not hold the DB transaction open waiting on the broker. This is the
    // simple "best-effort outbox" tradeoff - docs/08-kafka-event-driven.md
    // covers upgrading this to a transactional outbox table if you need
    // stronger exactly-once guarantees between the DB write and the publish.
    @Transactional
    public Order createOrder(CreateOrderRequest request) {
        // Reserve stock synchronously BEFORE writing the order - this is
        // the one dependency that must block checkout, because accepting
        // an order for something out of stock is worse than a slower
        // checkout. Runs before we open the DB write below so a stock
        // failure never leaves a half-written order behind.
        for (CreateOrderRequest.Item i : request.items()) {
            productServiceClient.reserveStock(i.productId(), i.quantity());
        }

        Order order = new Order();
        order.setUserId(request.userId());

        long total = 0;
        for (CreateOrderRequest.Item i : request.items()) {
            OrderItem item = new OrderItem();
            item.setProductId(i.productId());
            item.setProductName(i.productName());
            item.setQuantity(i.quantity());
            item.setPriceCents(i.priceCents());
            order.addItem(item);
            total += i.priceCents() * i.quantity();
        }
        order.setTotalCents(total);

        Order saved = orderRepository.save(order);

        eventPublisher.publishOrderCreated(new OrderCreatedEvent(
                saved.getId(),
                saved.getUserId(),
                saved.getTotalCents(),
                saved.getCurrency(),
                saved.getItems().stream()
                        .map(it -> new OrderCreatedEvent.Item(it.getProductId(), it.getProductName(), it.getQuantity(), it.getPriceCents()))
                        .collect(Collectors.toList()),
                UUID.randomUUID().toString()
        ));

        return saved;
    }

    @Transactional(readOnly = true)
    public Order getOrder(UUID id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new OrderNotFoundException(id));
    }

    @Transactional(readOnly = true)
    public Page<Order> listOrdersForUser(String userId, Pageable pageable) {
        return orderRepository.findByUserId(userId, pageable);
    }

    public static class OrderNotFoundException extends RuntimeException {
        public OrderNotFoundException(UUID id) {
            super("order not found: " + id);
        }
    }
}
