package com.scalecart.order.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.util.UUID;

@Entity
@Table(name = "order_items")
@Getter
@Setter
public class OrderItem {

    @Id
    @GeneratedValue
    private UUID id;

    // @JsonIgnore breaks what would otherwise be infinite recursion when
    // Jackson serializes an Order: Order -> items -> OrderItem.order ->
    // items -> ... Nothing downstream needs the parent order embedded
    // inside each of its own items anyway - the frontend gets the order's
    // id once, at the top level (see GET /orders/:id).
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id")
    @JsonIgnore
    private Order order;

    @Column(name = "product_id", nullable = false)
    private String productId;

    @Column(name = "product_name", nullable = false)
    private String productName;

    @Column(nullable = false)
    private int quantity;

    @Column(name = "price_cents", nullable = false)
    private long priceCents;
}
