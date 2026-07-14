"use client";

import * as React from "react";
import { useRouter } from "next/navigation";

import { apiFetch, ApiError } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

interface InviteInfo {
  name: string;
  email: string;
  type: string;
  organization: string;
}

export function AcceptInviteForm({ token, type }: { token: string; type: string }) {
  const router = useRouter();
  const [info, setInfo] = React.useState<InviteInfo | null>(null);
  const [loadError, setLoadError] = React.useState<string | null>(null);
  const [loading, setLoading] = React.useState(true);

  const [password, setPassword] = React.useState("");
  const [confirm, setConfirm] = React.useState("");
  const [formError, setFormError] = React.useState<string | null>(null);
  const [submitting, setSubmitting] = React.useState(false);

  // Validate the token on mount. This GET also seeds the XSRF-TOKEN cookie the
  // accept POST needs for CSRF.
  React.useEffect(() => {
    if (!token || !type) {
      setLoadError("This invitation link is missing information.");
      setLoading(false);
      return;
    }
    const query = new URLSearchParams({ token, type }).toString();
    apiFetch<InviteInfo>(`/api/v1/invitations?${query}`)
      .then((data) => setInfo(data))
      .catch((err) => {
        setLoadError(
          err instanceof ApiError
            ? err.message
            : "This invitation link is invalid or has expired.",
        );
      })
      .finally(() => setLoading(false));
  }, [token, type]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setFormError(null);

    if (password.length < 8) {
      setFormError("Password must be at least 8 characters.");
      return;
    }
    if (password !== confirm) {
      setFormError("Passwords do not match.");
      return;
    }

    setSubmitting(true);
    try {
      const res = await apiFetch<{ redirect_to: string }>(
        "/api/v1/invitations/accept",
        { method: "POST", body: JSON.stringify({ token, type, password }) },
      );
      router.push(res.redirect_to);
    } catch (err) {
      setFormError(
        err instanceof ApiError ? err.message : "Something went wrong. Please try again.",
      );
      setSubmitting(false);
    }
  }

  if (loading) {
    return <p className="text-body text-muted-foreground">Checking your invitation…</p>;
  }

  if (loadError) {
    return (
      <div className="flex flex-col gap-4">
        <p
          role="alert"
          className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-body text-destructive"
        >
          {loadError}
        </p>
        <Button variant="outline" onClick={() => router.push("/login")}>
          Back to sign in
        </Button>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <div className="flex flex-col gap-1">
        <p className="text-body text-muted-foreground">
          Welcome, <span className="font-medium text-foreground">{info?.name}</span>.
          Set a password to activate your {info?.organization} account.
        </p>
        <p className="text-label text-muted-foreground">{info?.email}</p>
      </div>

      <div className="flex flex-col gap-2">
        <Label htmlFor="password">New password</Label>
        <Input
          id="password"
          type="password"
          autoComplete="new-password"
          placeholder="At least 8 characters"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />
      </div>

      <div className="flex flex-col gap-2">
        <Label htmlFor="confirm">Confirm password</Label>
        <Input
          id="confirm"
          type="password"
          autoComplete="new-password"
          placeholder="Re-enter password"
          value={confirm}
          onChange={(e) => setConfirm(e.target.value)}
          required
        />
      </div>

      {formError && (
        <p
          role="alert"
          className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-body text-destructive"
        >
          {formError}
        </p>
      )}

      <Button type="submit" className="w-full" disabled={submitting}>
        {submitting ? "Activating…" : "Set password & continue"}
      </Button>
    </form>
  );
}
