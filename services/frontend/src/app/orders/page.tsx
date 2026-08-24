"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useAuth } from "@/lib/auth-context";
import { fetchOrders, formatPrice, Order } from "@/lib/api";
import { EmptyState, ErrorBanner } from "@/components/EmptyState";
import { StatusBadge } from "@/components/StatusBadge";
import { Spinner } from "@/components/Spinner";

export default function OrdersPage() {
  const { user, loading: authLoading } = useAuth();
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!user) {
      setLoading(false);
      return;
    }
    fetchOrders(user.id)
      .then(setOrders)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, [user]);

  if (authLoading || loading) {
    return (
      <div className="flex justify-center py-16">
        <Spinner />
      </div>
    );
  }

  if (!user) {
    return (
      <EmptyState
        title="Sign in to view your orders"
        action={
          <Link href="/login" className="btn-primary">
            Sign in
          </Link>
        }
      />
    );
  }

  if (error) return <ErrorBanner message={`Could not load orders: ${error}`} />;

  if (orders.length === 0) {
    return (
      <EmptyState
        title="No orders yet"
        description="Orders you place will show up here."
        action={
          <Link href="/" className="btn-primary">
            Browse catalog
          </Link>
        }
      />
    );
  }

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold text-ink-900">Your orders</h1>
      <div className="card divide-y divide-ink-100">
        {orders.map((order) => (
          <Link
            key={order.id}
            href={`/orders/${order.id}`}
            className="flex items-center justify-between px-5 py-4 hover:bg-ink-50"
          >
            <div>
              <p className="font-medium text-ink-900">Order #{order.id.slice(0, 8)}</p>
              <p className="text-sm text-ink-500">{new Date(order.createdAt).toLocaleString()}</p>
            </div>
            <div className="flex items-center gap-4">
              <span className="font-medium text-ink-900">
                {formatPrice(order.totalCents, order.currency)}
              </span>
              <StatusBadge status={order.status} />
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}
