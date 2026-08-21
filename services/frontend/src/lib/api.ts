// Every backend call goes through one base URL: the Istio ingress gateway
// in k8s, or the Nginx reverse-proxy path in docker-compose (see
// services/frontend/nginx.conf). The frontend never talks to a service's
// pod IP directly - this is what makes mTLS, retries, and canary routing
// (all configured at the mesh level) transparent to this code.
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || "/api";

export interface Product {
  id: string;
  name: string;
  description: string;
  priceCents: number;
  currency: string;
  category: string;
  stockQty: number;
}

export async function fetchProducts(category?: string): Promise<Product[]> {
  const res = await fetch(`${API_BASE_URL}/products${category ? `?category=${category}` : ""}`, {
    cache: "no-store",
  });
  if (!res.ok) throw new Error(`failed to fetch products: ${res.status}`);
  const data = await res.json();
  return data.products ?? [];
}

export async function login(email: string, password: string): Promise<{ token: string }> {
  const res = await fetch(`${API_BASE_URL}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) throw new Error("login_failed");
  return res.json();
}

export function formatPrice(cents: number, currency: string): string {
  return new Intl.NumberFormat("en-US", { style: "currency", currency }).format(cents / 100);
}
