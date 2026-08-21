"use client";

import { useEffect, useState } from "react";
import { fetchProducts, formatPrice, Product } from "@/lib/api";

export default function HomePage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchProducts()
      .then(setProducts)
      .catch((e) => setError(e.message));
  }, []);

  if (error) {
    return <p role="alert">Could not load products: {error}</p>;
  }

  return (
    <div>
      <h1>Catalog</h1>
      <ul style={{ listStyle: "none", padding: 0, display: "grid", gap: "1rem" }}>
        {products.map((p) => (
          <li key={p.id} style={{ border: "1px solid #eee", padding: "1rem" }}>
            <strong>{p.name}</strong>
            <p>{p.description}</p>
            <span>{formatPrice(p.priceCents, p.currency)}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
