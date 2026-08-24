// Every backend call goes through one base URL: the Istio ingress gateway
// in k8s, or the Nginx reverse-proxy path in docker-compose (see
// services/frontend/nginx.conf). The frontend never talks to a service's
// pod IP directly - this is what makes mTLS, retries, and canary routing
// (all configured at the mesh level) transparent to this code.
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || "/api";

export interface Product {
  id: string;
  sku: string;
  name: string;
  description: string;
  priceCents: number;
  currency: string;
  category: string;
  stockQty: number;
}

export interface CartItem {
  product_id: string;
  name: string;
  price_cents: number;
  quantity: number;
}

export interface Cart {
  user_id: string;
  items: CartItem[];
}

export type OrderStatus = "PENDING" | "PAID" | "CANCELLED" | "FAILED";

export interface OrderItem {
  productId: string;
  productName: string;
  quantity: number;
  priceCents: number;
}

export interface Order {
  id: string;
  userId: string;
  status: OrderStatus;
  totalCents: number;
  currency: string;
  createdAt: string;
  items: OrderItem[];
}

export interface Payment {
  id: string;
  orderId: string;
  userId: string;
  amountCents: string;
  currency: string;
  status: "AUTHORIZED" | "CAPTURED" | "FAILED";
  createdAt: string;
}

class ApiError extends Error {
  constructor(
    message: string,
    public status: number
  ) {
    super(message);
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE_URL}${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", ...(init?.headers || {}) },
    cache: "no-store",
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new ApiError(body.error || `request failed (${res.status})`, res.status);
  }
  if (res.status === 204) return undefined as T;
  return res.json();
}

// ---------- auth-service ----------
export async function login(email: string, password: string): Promise<{ token: string }> {
  return request("/auth/login", { method: "POST", body: JSON.stringify({ email, password }) });
}

export async function register(email: string, password: string, fullName: string) {
  return request<{ id: string; email: string; fullName: string }>("/auth/register", {
    method: "POST",
    body: JSON.stringify({ email, password, fullName }),
  });
}

// ---------- product-service ----------
export async function fetchProducts(category?: string): Promise<Product[]> {
  const data = await request<{ products: Product[] }>(
    `/products${category ? `?category=${encodeURIComponent(category)}` : ""}`
  );
  return data.products ?? [];
}

// ---------- cart-service ----------
export async function fetchCart(userId: string): Promise<Cart> {
  return request(`/cart/${userId}`);
}

export async function addCartItem(userId: string, item: CartItem): Promise<Cart> {
  return request(`/cart/${userId}/items`, { method: "POST", body: JSON.stringify(item) });
}

export async function removeCartItem(userId: string, productId: string): Promise<Cart> {
  return request(`/cart/${userId}/items/${productId}`, { method: "DELETE" });
}

export async function clearCart(userId: string): Promise<void> {
  await request(`/cart/${userId}`, { method: "DELETE" });
}

// ---------- order-service ----------
export async function createOrder(userId: string, items: OrderItem[]): Promise<Order> {
  return request("/orders", { method: "POST", body: JSON.stringify({ userId, items }) });
}

export async function fetchOrder(orderId: string): Promise<Order> {
  return request(`/orders/${orderId}`);
}

export async function fetchOrders(userId: string): Promise<Order[]> {
  const data = await request<{ content: Order[] }>(`/orders?userId=${encodeURIComponent(userId)}&size=50`);
  return data.content ?? [];
}

// ---------- payment-service ----------
export async function fetchPayment(orderId: string): Promise<Payment | null> {
  try {
    return await request<Payment>(`/payments/${orderId}`);
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) return null;
    throw e;
  }
}

// ---------- formatting helpers ----------
export function formatPrice(cents: number, currency = "USD"): string {
  return new Intl.NumberFormat("en-US", { style: "currency", currency }).format(cents / 100);
}

export function cartTotalCents(cart: Cart): number {
  return cart.items.reduce((sum, i) => sum + i.price_cents * i.quantity, 0);
}
