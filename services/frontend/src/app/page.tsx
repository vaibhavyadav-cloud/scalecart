"use client";

import { useEffect, useMemo, useState } from "react";
import { fetchProducts, Product } from "@/lib/api";
import { ProductCard } from "@/components/ProductCard";
import { EmptyState, ErrorBanner } from "@/components/EmptyState";
import { Spinner } from "@/components/Spinner";

export default function HomePage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [category, setCategory] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    setError(null);
    fetchProducts()
      .then(setProducts)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  const categories = useMemo(
    () => Array.from(new Set(products.map((p) => p.category))).sort(),
    [products]
  );

  const visible = category ? products.filter((p) => p.category === category) : products;

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-ink-900">Catalog</h1>
        <p className="mt-1 text-sm text-ink-500">Browse products served live from product-service.</p>
      </div>

      {error && (
        <div className="mb-6">
          <ErrorBanner message={`Could not load products: ${error}`} />
        </div>
      )}

      {loading ? (
        <div className="flex justify-center py-16">
          <Spinner />
        </div>
      ) : products.length === 0 && !error ? (
        <EmptyState
          title="No products yet"
          description="Add one via POST /products on product-service to see it here - see docs/17-local-quickstart.md."
        />
      ) : (
        <>
          {categories.length > 1 && (
            <div className="mb-6 flex flex-wrap gap-2">
              <button
                onClick={() => setCategory(null)}
                className={`rounded-full px-3 py-1.5 text-sm font-medium ${
                  category === null ? "bg-brand-600 text-white" : "bg-white text-ink-600 hover:bg-ink-100"
                }`}
              >
                All
              </button>
              {categories.map((c) => (
                <button
                  key={c}
                  onClick={() => setCategory(c)}
                  className={`rounded-full px-3 py-1.5 text-sm font-medium ${
                    category === c ? "bg-brand-600 text-white" : "bg-white text-ink-600 hover:bg-ink-100"
                  }`}
                >
                  {c}
                </button>
              ))}
            </div>
          )}

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {visible.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </>
      )}
    </div>
  );
}
