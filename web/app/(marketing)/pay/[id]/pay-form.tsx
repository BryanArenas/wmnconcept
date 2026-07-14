"use client";

import * as React from "react";
import { CheckCircle2 } from "lucide-react";

import { apiFetch, ApiError } from "@/lib/api";
import { Button } from "@/components/ui/button";

interface PaymentInfo {
  id: string;
  amount_cents: number;
  status: "draft" | "sent" | "paid" | "void";
  agency_name: string;
  inspection_type: string;
  property_address: string;
  placeholder: boolean;
}

function money(cents: number) {
  return `$${(cents / 100).toFixed(2)}`;
}

const TYPE_LABEL: Record<string, string> = {
  wind_mitigation: "Wind Mitigation",
  four_point: "4-Point Inspection",
  roof_condition: "Roof Condition Letter",
  general_home: "General Home Inspection",
  wind_four_combo: "Wind + 4-Point Combo",
  hoa_master_wind: "HOA / Condo Master Wind",
  commercial_wind: "Commercial Wind Mitigation",
};

export function PayForm({ id }: { id: string }) {
  const [info, setInfo] = React.useState<PaymentInfo | null>(null);
  const [loadError, setLoadError] = React.useState<string | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [submitting, setSubmitting] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    apiFetch<PaymentInfo>(`/api/v1/pay/${id}`)
      .then(setInfo)
      .catch((err) =>
        setLoadError(
          err instanceof ApiError ? err.message : "This payment link is invalid.",
        ),
      )
      .finally(() => setLoading(false));
  }, [id]);

  async function pay() {
    setSubmitting(true);
    setError(null);
    try {
      const updated = await apiFetch<PaymentInfo>(`/api/v1/pay/${id}/confirm`, {
        method: "POST",
      });
      setInfo(updated);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Payment could not be processed.");
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) return <p className="text-body text-muted-foreground">Loading invoice…</p>;

  if (loadError) {
    return (
      <p
        role="alert"
        className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-body text-destructive"
      >
        {loadError}
      </p>
    );
  }

  if (!info) return null;

  const paid = info.status === "paid";

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-col gap-1 rounded-lg border border-border bg-muted/30 p-4">
        <div className="flex items-baseline justify-between">
          <span className="text-body text-muted-foreground">Amount due</span>
          <span className="font-serif text-display-md">{money(info.amount_cents)}</span>
        </div>
        <div className="mt-2 flex flex-col gap-1 text-label text-muted-foreground">
          <span>{TYPE_LABEL[info.inspection_type] ?? info.inspection_type}</span>
          <span>{info.property_address}</span>
          <span>Billed by {info.agency_name}</span>
        </div>
      </div>

      {paid ? (
        <div className="flex items-center gap-2 rounded-md border border-primary/30 bg-primary/5 px-3 py-3 text-body text-foreground">
          <CheckCircle2 className="h-5 w-5 text-primary" />
          Payment received. Thank you!
        </div>
      ) : (
        <>
          {info.placeholder && (
            <p className="rounded-md border border-border bg-muted/40 px-3 py-2 text-label text-muted-foreground">
              This is a placeholder checkout — no real card is charged. Clicking
              pay simulates a successful payment so the flow can be tested.
            </p>
          )}
          {error && (
            <p
              role="alert"
              className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-body text-destructive"
            >
              {error}
            </p>
          )}
          <Button className="w-full" onClick={pay} disabled={submitting}>
            {submitting ? "Processing…" : `Pay ${money(info.amount_cents)}`}
          </Button>
        </>
      )}
    </div>
  );
}
