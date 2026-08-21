import React from "react";

export const metadata = {
  title: "ScaleCart",
  description: "Cloud-native e-commerce platform demo",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body style={{ fontFamily: "system-ui, sans-serif", margin: 0 }}>
        <header style={{ padding: "1rem", borderBottom: "1px solid #ddd" }}>
          <strong>ScaleCart</strong>
        </header>
        <main style={{ padding: "1.5rem" }}>{children}</main>
      </body>
    </html>
  );
}
