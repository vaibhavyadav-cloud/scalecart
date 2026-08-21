"use client";

import { useState, FormEvent } from "react";
import { login } from "@/lib/api";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [status, setStatus] = useState<string | null>(null);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setStatus("Signing in...");
    try {
      const { token } = await login(email, password);
      localStorage.setItem("scalecart_token", token);
      setStatus("Signed in.");
    } catch {
      setStatus("Invalid credentials.");
    }
  }

  return (
    <form onSubmit={handleSubmit} style={{ maxWidth: 320, display: "grid", gap: "0.75rem" }}>
      <h1>Sign in</h1>
      <input
        type="email"
        placeholder="Email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        required
      />
      <input
        type="password"
        placeholder="Password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        required
      />
      <button type="submit">Sign in</button>
      {status && <p>{status}</p>}
    </form>
  );
}
