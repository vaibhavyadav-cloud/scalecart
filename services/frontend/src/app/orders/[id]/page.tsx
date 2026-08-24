"use client";

import { useEffect, useRef, useState } from "react";
import { useParams } from "next/navigation";
import { fetchOrder, fetchPayment, formatPrice, Order, Payment } from "@/lib/api";
import { StatusBadge } from "@/components/StatusBadge";
import { ErrorBanner } from "@/components/EmptyState";
import { Spinner } from "@/components/Spinner";

const TERMINAL_STATUSES = new Set(["PAID", "FAILED", "CANCELLED"]);
const POLL_INTERVAL_MS = 2000;
const POLL_TIMEOUT_MS = 30000;

// order-service returns "order accepted" the instant it's written -
// payment capture and the resulting status flip both happen afterward,
// asynchronously, over Kafka (order-service's PaymentEventConsumer, see
// docs/08-kafka-event-driven.md). This page polls both order-service AND
// payment-service until either reaches a terminal state, so a viewer can
// watch PENDING -> PAID happen live instead of the UI just lying and
// showing a fake "success" the moment the order is created.
export default function OrderDetailPage() {
  const params = useParams<{ id: string }>();
  const [order, setOrder] = useState<Order | null>(null);
  const [payment, setPayment] = useState<Payment | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [polling, setPolling] = useState(true);
  const startedAt = useRef(Date.now());

  useEffect(() => {
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout>;

    async function tick() {
      try {
        const [nextOrder, nextPayment] = await Promise.all([
          fetchOrder(params.id),
          fetchPayment(params.id),
        ]);
        if (cancelled) return;
        setOrder(nextOrder);
        setPayment(nextPayment);
        setError(null);

        const done = TERMINAL_STATUSES.has(nextOrder.status);
        const timedOut = Date.now() - startedAt.current > POLL_TIMEOUT_MS;
        if (done || timedOut) {
          setPolling(false);
          return;
        }
        timer = setTimeout(tick, POLL_INTERVAL_MS);
      } catch (e) {
        if (cancelled) return;
        setError(e instanceof Error ? e.message : "failed to load order");
        setPolling(false);
      }
    }

    tick();
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [params.id]);

  if (error) return <ErrorBanner message={`Could not load order: ${error}`} />;
  if (!order) {
    return (
      <div className="flex justify-center py-16">
        <Spinner />
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-lg">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-ink-900">Order #{order.id.slice(0, 8)}</h1>
        <StatusBadge status={order.status} />
      </div>

      {polling && (
        <div className="mb-4 flex items-center gap-2 rounded-lg border border-brand-100 bg-brand-50 px-4 py-3 text-sm text-brand-700">
          <Spinner className="h-4 w-4" />
          Waiting on payment-service to process this asynchronously over Kafka...
        </div>
      )}

      <div className="card divide-y divide-ink-100">
        {order.items.map((item) => (
          <div key={item.productId} className="flex items-center justify-between px-5 py-3 text-sm">
            <span className="text-ink-700">
              {item.productName} × {item.quantity}
            </span>
            <span className="font-medium text-ink-900">{formatPrice(item.priceCents * item.quantity)}</span>
          </div>
        ))}
        <div className="flex items-center justify-between px-5 py-4">
          <span className="font-semibold text-ink-900">Total</span>
          <span className="text-xl font-bold text-ink-900">{formatPrice(order.totalCents, order.currency)}</span>
        </div>
      </div>

      <div className="card mt-4 space-y-3 p-5">
        <div className="flex items-center justify-between text-sm">
          <span className="text-ink-500">Order status</span>
          <StatusBadge status={order.status} />
        </div>
        <div className="flex items-center justify-between text-sm">
          <span className="text-ink-500">Payment status</span>
          {payment ? (
            <StatusBadge status={payment.status} />
          ) : (
            <span className="text-ink-400">not processed yet</span>
          )}
        </div>
        <div className="flex items-center justify-between text-sm">
          <span className="text-ink-500">Placed</span>
          <span className="text-ink-700">{new Date(order.createdAt).toLocaleString()}</span>
        </div>
      </div>
    </div>
  );
}
