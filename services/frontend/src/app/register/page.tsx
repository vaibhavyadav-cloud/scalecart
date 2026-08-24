"use client";

import { useState, FormEvent } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { register as registerRequest, login as loginRequest } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { ErrorBanner } from "@/components/EmptyState";
import { Spinner } from "@/components/Spinner";

export default function RegisterPage() {
  const { login } = useAuth();
  const router = useRouter();
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await registerRequest(email, password, fullName);
      // Registration doesn't itself return a session - log in immediately
      // after so the new user lands on the catalog already signed in,
      // instead of being sent back to a login form they'd have to fill
      // out a second time.
      const { token } = await loginRequest(email, password);
      login(token);
      router.push("/");
    } catch (err) {
      const message = err instanceof Error ? err.message : "registration_failed";
      setError(
        message === "email_already_registered"
          ? "An account with that email already exists."
          : "Password must be at least 8 characters."
      );
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="mx-auto max-w-sm">
      <div className="card p-6">
        <h1 className="text-xl font-bold text-ink-900">Create an account</h1>
        <p className="mt-1 text-sm text-ink-500">Start shopping on ScaleCart.</p>

        <form onSubmit={handleSubmit} className="mt-6 space-y-4">
          <div>
            <label className="label" htmlFor="fullName">
              Full name
            </label>
            <input
              id="fullName"
              type="text"
              className="input"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              required
            />
          </div>
          <div>
            <label className="label" htmlFor="email">
              Email
            </label>
            <input
              id="email"
              type="email"
              className="input"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
          <div>
            <label className="label" htmlFor="password">
              Password
            </label>
            <input
              id="password"
              type="password"
              className="input"
              minLength={8}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
            <p className="mt-1 text-xs text-ink-400">At least 8 characters.</p>
          </div>

          {error && <ErrorBanner message={error} />}

          <button type="submit" disabled={submitting} className="btn-primary w-full">
            {submitting ? <Spinner className="h-4 w-4" color="text-white" /> : "Create account"}
          </button>
        </form>

        <p className="mt-6 text-center text-sm text-ink-500">
          Already have an account?{" "}
          <Link href="/login" className="font-medium text-brand-600 hover:text-brand-700">
            Sign in
          </Link>
        </p>
      </div>
    </div>
  );
}
