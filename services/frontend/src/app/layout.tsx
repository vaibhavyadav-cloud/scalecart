import React from "react";
import { Inter } from "next/font/google";
import "./globals.css";
import { AuthProvider } from "@/lib/auth-context";
import { CartProvider } from "@/lib/cart-context";
import { Navbar } from "@/components/Navbar";

// next/font self-hosts Google Fonts at build time - no runtime request to
// fonts.googleapis.com, which matters for a static export served from a
// CDN/nginx with no server-side rendering to inject a preload hint.
const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });

export const metadata = {
  title: "ScaleCart",
  description: "Cloud-native e-commerce platform demo",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="min-h-screen bg-ink-50 font-sans text-ink-900">
        <AuthProvider>
          <CartProvider>
            <Navbar />
            <main className="mx-auto max-w-5xl px-6 py-8">{children}</main>
          </CartProvider>
        </AuthProvider>
      </body>
    </html>
  );
}
