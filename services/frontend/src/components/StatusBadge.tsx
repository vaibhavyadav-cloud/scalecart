const STYLES: Record<string, string> = {
  PENDING: "bg-amber-50 text-amber-700 border-amber-200",
  AUTHORIZED: "bg-amber-50 text-amber-700 border-amber-200",
  PAID: "bg-emerald-50 text-emerald-700 border-emerald-200",
  CAPTURED: "bg-emerald-50 text-emerald-700 border-emerald-200",
  FAILED: "bg-red-50 text-red-700 border-red-200",
  CANCELLED: "bg-ink-100 text-ink-600 border-ink-200",
};

// One shared vocabulary of status colors for both order-service's
// OrderStatus and payment-service's payment status - see
// services/order-service/.../OrderStatus.java and
// services/payment-service's `status` column. Kept as a single lookup
// table so a new status added to either backend only needs one new line
// here, not a scattered set of if/else chains across pages.
export function StatusBadge({ status }: { status: string }) {
  const style = STYLES[status] ?? "bg-ink-100 text-ink-600 border-ink-200";
  return (
    <span className={`inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-medium ${style}`}>
      {status}
    </span>
  );
}
