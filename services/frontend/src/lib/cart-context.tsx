"use client";

import { createContext, useCallback, useContext, useEffect, useState, ReactNode } from "react";
import { addCartItem, Cart, CartItem, clearCart, fetchCart, removeCartItem } from "./api";
import { useAuth } from "./auth-context";

interface CartContextValue {
  cart: Cart | null;
  loading: boolean;
  itemCount: number;
  refresh: () => Promise<void>;
  addItem: (item: CartItem) => Promise<void>;
  removeItem: (productId: string) => Promise<void>;
  clear: () => Promise<void>;
}

const CartContext = createContext<CartContextValue | undefined>(undefined);

// The cart lives in cart-service (Redis), keyed by userId - see
// services/cart-service. This context is just a thin, shared cache in
// front of that so every page (navbar badge, cart page, checkout) reads
// the same in-memory copy instead of each re-fetching independently.
export function CartProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const [cart, setCart] = useState<Cart | null>(null);
  const [loading, setLoading] = useState(false);

  const refresh = useCallback(async () => {
    if (!user) {
      setCart(null);
      return;
    }
    setLoading(true);
    try {
      setCart(await fetchCart(user.id));
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  async function addItem(item: CartItem) {
    if (!user) throw new Error("must be logged in");
    setCart(await addCartItem(user.id, item));
  }

  async function removeItem(productId: string) {
    if (!user) throw new Error("must be logged in");
    setCart(await removeCartItem(user.id, productId));
  }

  async function clear() {
    if (!user) return;
    await clearCart(user.id);
    setCart({ user_id: user.id, items: [] });
  }

  const itemCount = cart?.items.reduce((sum, i) => sum + i.quantity, 0) ?? 0;

  return (
    <CartContext.Provider value={{ cart, loading, itemCount, refresh, addItem, removeItem, clear }}>
      {children}
    </CartContext.Provider>
  );
}

export function useCart(): CartContextValue {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error("useCart must be used within CartProvider");
  return ctx;
}
