"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { useCart } from "@/lib/cart-context";

export function Navbar() {
  const { user, logout } = useAuth();
  const { itemCount } = useCart();
  const router = useRouter();

  function handleLogout() {
    logout();
    router.push("/");
  }

  return (
    <header className="sticky top-0 z-10 border-b border-ink-100 bg-white/90 backdrop-blur">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-6 py-4">
        <Link href="/" className="text-lg font-bold tracking-tight text-ink-900">
          Scale<span className="text-brand-600">Cart</span>
        </Link>

        <nav className="flex items-center gap-1 text-sm">
          <Link href="/" className="rounded-lg px-3 py-2 text-ink-600 hover:bg-ink-50 hover:text-ink-900">
            Catalog
          </Link>

          {user && (
            <Link href="/orders" className="rounded-lg px-3 py-2 text-ink-600 hover:bg-ink-50 hover:text-ink-900">
              Orders
            </Link>
          )}

          <Link
            href="/cart"
            className="relative rounded-lg px-3 py-2 text-ink-600 hover:bg-ink-50 hover:text-ink-900"
          >
            Cart
            {itemCount > 0 && (
              <span className="absolute -right-0.5 -top-0.5 flex h-[18px] min-w-[18px] items-center justify-center rounded-full bg-brand-600 px-1 text-[10px] font-semibold text-white">
                {itemCount}
              </span>
            )}
          </Link>

          {user ? (
            <div className="ml-2 flex items-center gap-2 border-l border-ink-100 pl-3">
              <span className="hidden text-ink-500 sm:inline">{user.email}</span>
              <button onClick={handleLogout} className="btn-secondary !px-3 !py-1.5">
                Sign out
              </button>
            </div>
          ) : (
            <div className="ml-2 flex items-center gap-2 border-l border-ink-100 pl-3">
              <Link href="/login" className="btn-secondary !px-3 !py-1.5">
                Sign in
              </Link>
              <Link href="/register" className="btn-primary !px-3 !py-1.5">
                Sign up
              </Link>
            </div>
          )}
        </nav>
      </div>
    </header>
  );
}
