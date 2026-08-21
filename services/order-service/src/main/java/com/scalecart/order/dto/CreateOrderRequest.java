package com.scalecart.order.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record CreateOrderRequest(
        @NotBlank String userId,
        @NotEmpty @Valid List<Item> items
) {
    public record Item(
            @NotBlank String productId,
            @NotBlank String productName,
            int quantity,
            long priceCents
    ) {}
}
