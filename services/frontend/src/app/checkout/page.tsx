"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { useCart } from "@/lib/cart-context";
import { cartTotalCents, createOrder, formatPrice } from "@/lib/api";
import { EmptyState, ErrorBanner } from "@/components/EmptyState";
import { Spinner } from "@/components/Spinner";

export default function CheckoutPage() {
  const { user } = useAuth();
  const { cart, clear } = useCart();
  const router = useRouter();
  const [placing, setPlacing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!user) {
    return (
      <EmptyState
        title="Sign in to check out"
        action={
          <Link href="/login" className="btn-primary">
            Sign in
          </Link>
        }
      />
    );
  }

  if (!cart || cart.items.length === 0) {
    return (
      <EmptyState
        title="Nothing to check out"
        description="Your cart is empty."
        action={
          <Link href="/" className="btn-primary">
            Browse catalog
          </Link>
        }
      />
    );
  }

  const total = cartTotalCents(cart);

  // This is the single synchronous call in the whole checkout flow:
  // order-service writes the order row AND (inline, before responding)
  // calls product-service to reserve stock - see
  // OrderService.createOrder / ProductServiceClient.java and
  // docs/02-microservices-and-tradeoffs.md. Everything after this
  // response (payment capture, the order's status flipping to PAID/
  // FAILED, the notification email) happens asynchronously via Kafka,
  // which is why the next page polls instead of showing a final result
  // immediately.
  async function handlePlaceOrder() {
    setError(null);
    setPlacing(true);
    try {
      const order = await createOrder(
        user!.id,
        cart!.items.map((i) => ({
          productId: i.product_id,
          productName: i.name,
          quantity: i.quantity,
          priceCents: i.price_cents,
        }))
      );
      await clear();
      router.push(`/orders/detail?id=${order.id}`);
    } catch (e) {
      setError(
        e instanceof Error && e.message === "insufficient_stock"
          ? "One of the items in your cart just sold out. Please update your cart."
          : "Could not place your order. Please try again."
      );
    } finally {
      setPlacing(false);
    }
  }

  return (
    <div className="mx-auto max-w-lg">
      <h1 className="mb-6 text-2xl font-bold text-ink-900">Checkout</h1>

      <div className="card divide-y divide-ink-100">
        {cart.items.map((item) => (
          <div key={item.product_id} className="flex items-center justify-between px-5 py-3 text-sm">
            <span className="text-ink-700">
              {item.name} × {item.quantity}
            </span>
            <span className="font-medium text-ink-900">{formatPrice(item.price_cents * item.quantity)}</span>
          </div>
        ))}
        <div className="flex items-center justify-between px-5 py-4">
          <span className="font-semibold text-ink-900">Total</span>
          <span className="text-xl font-bold text-ink-900">{formatPrice(total)}</span>
        </div>
      </div>

      {error && (
        <div className="mt-4">
          <ErrorBanner message={error} />
        </div>
      )}

      <button onClick={handlePlaceOrder} disabled={placing} className="btn-primary mt-4 w-full">
        {placing ? <Spinner className="h-4 w-4" color="text-white" /> : `Place order · ${formatPrice(total)}`}
      </button>
      <p className="mt-3 text-center text-xs text-ink-400">
        Payment is simulated - order-service, payment-service, and notification-service coordinate over Kafka
        after this click. See docs/08-kafka-event-driven.md.
      </p>
    </div>
  );
}
