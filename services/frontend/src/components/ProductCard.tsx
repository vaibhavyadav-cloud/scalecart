"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Product, formatPrice } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { useCart } from "@/lib/cart-context";
import { Spinner } from "./Spinner";

export function ProductCard({ product }: { product: Product }) {
  const { user } = useAuth();
  const { addItem } = useCart();
  const router = useRouter();
  const [adding, setAdding] = useState(false);
  const [added, setAdded] = useState(false);

  async function handleAddToCart() {
    if (!user) {
      router.push("/login");
      return;
    }
    setAdding(true);
    try {
      await addItem({
        product_id: product.id,
        name: product.name,
        price_cents: product.priceCents,
        quantity: 1,
      });
      setAdded(true);
      setTimeout(() => setAdded(false), 1500);
    } finally {
      setAdding(false);
    }
  }

  const outOfStock = product.stockQty <= 0;

  return (
    <div className="card flex flex-col p-5">
      <div className="mb-3 flex items-start justify-between gap-2">
        <span className="rounded-full bg-brand-50 px-2.5 py-0.5 text-xs font-medium text-brand-700">
          {product.category}
        </span>
        {outOfStock && (
          <span className="rounded-full bg-ink-100 px-2.5 py-0.5 text-xs font-medium text-ink-500">
            Out of stock
          </span>
        )}
      </div>

      <h3 className="text-base font-semibold text-ink-900">{product.name}</h3>
      <p className="mt-1 line-clamp-2 flex-1 text-sm text-ink-500">{product.description}</p>

      <div className="mt-4 flex items-center justify-between">
        <span className="text-lg font-semibold text-ink-900">
          {formatPrice(product.priceCents, product.currency)}
        </span>
        <button
          onClick={handleAddToCart}
          disabled={adding || outOfStock}
          className="btn-primary !px-3 !py-2 text-sm"
        >
          {adding ? <Spinner className="h-4 w-4" color="text-white" /> : added ? "Added ✓" : "Add to cart"}
        </button>
      </div>
    </div>
  );
}
