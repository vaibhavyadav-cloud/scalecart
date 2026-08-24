"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { useCart } from "@/lib/cart-context";
import { cartTotalCents, formatPrice } from "@/lib/api";
import { EmptyState } from "@/components/EmptyState";
import { Spinner } from "@/components/Spinner";

export default function CartPage() {
  const { user, loading: authLoading } = useAuth();
  const { cart, loading, removeItem } = useCart();
  const router = useRouter();
  const [removingId, setRemovingId] = useState<string | null>(null);

  if (authLoading) {
    return (
      <div className="flex justify-center py-16">
        <Spinner />
      </div>
    );
  }

  if (!user) {
    return (
      <EmptyState
        title="Sign in to view your cart"
        description="Your cart is tied to your account so it's still there next time you visit."
        action={
          <Link href="/login" className="btn-primary">
            Sign in
          </Link>
        }
      />
    );
  }

  async function handleRemove(productId: string) {
    setRemovingId(productId);
    try {
      await removeItem(productId);
    } finally {
      setRemovingId(null);
    }
  }

  if (loading && !cart) {
    return (
      <div className="flex justify-center py-16">
        <Spinner />
      </div>
    );
  }

  if (!cart || cart.items.length === 0) {
    return (
      <EmptyState
        title="Your cart is empty"
        description="Add something from the catalog to see it here."
        action={
          <Link href="/" className="btn-primary">
            Browse catalog
          </Link>
        }
      />
    );
  }

  const total = cartTotalCents(cart);

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold text-ink-900">Your cart</h1>

      <div className="card divide-y divide-ink-100">
        {cart.items.map((item) => (
          <div key={item.product_id} className="flex items-center justify-between gap-4 px-5 py-4">
            <div>
              <p className="font-medium text-ink-900">{item.name}</p>
              <p className="text-sm text-ink-500">
                {formatPrice(item.price_cents)} × {item.quantity}
              </p>
            </div>
            <div className="flex items-center gap-4">
              <span className="font-medium text-ink-900">
                {formatPrice(item.price_cents * item.quantity)}
              </span>
              <button
                onClick={() => handleRemove(item.product_id)}
                disabled={removingId === item.product_id}
                className="btn-danger !px-3 !py-1.5 text-sm"
              >
                {removingId === item.product_id ? (
                  <Spinner className="h-4 w-4" color="text-red-600" />
                ) : (
                  "Remove"
                )}
              </button>
            </div>
          </div>
        ))}
      </div>

      <div className="card mt-4 flex items-center justify-between px-5 py-4">
        <span className="text-sm font-medium text-ink-600">Total</span>
        <span className="text-xl font-bold text-ink-900">{formatPrice(total)}</span>
      </div>

      <button onClick={() => router.push("/checkout")} className="btn-primary mt-4 w-full">
        Proceed to checkout
      </button>
    </div>
  );
}
