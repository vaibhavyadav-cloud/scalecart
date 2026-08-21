package com.scalecart.order.controller;

import com.scalecart.order.dto.CreateOrderRequest;
import com.scalecart.order.model.Order;
import com.scalecart.order.service.OrderService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.util.UUID;

@RestController
@RequestMapping("/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    @PostMapping
    public ResponseEntity<Order> create(@Valid @RequestBody CreateOrderRequest request) {
        Order order = orderService.createOrder(request);
        return ResponseEntity.created(URI.create("/orders/" + order.getId())).body(order);
    }

    @GetMapping("/{id}")
    public Order get(@PathVariable UUID id) {
        return orderService.getOrder(id);
    }

    @GetMapping
    public Page<Order> list(@RequestParam String userId, Pageable pageable) {
        return orderService.listOrdersForUser(userId, pageable);
    }

    @ExceptionHandler(OrderService.OrderNotFoundException.class)
    public ResponseEntity<Object> handleNotFound(OrderService.OrderNotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(new ErrorBody(ex.getMessage()));
    }

    record ErrorBody(String error) {}
}
