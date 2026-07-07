"use client";

import { Receipt } from "lucide-react";
import { cn } from "@/lib/utils";
import type { Invoice, InvoiceStatus } from "@/lib/types";

const BILLING_LABEL: Record<string, string> = {
  fixed_rate: "Fixed rate",
  commission: "Commission",
};

// Status pill tints (§8.5): paid=emerald, sent=amber, void=muted, draft=stone.
const STATUS_PILL: Record<InvoiceStatus, string> = {
  paid: "bg-emerald-50 text-emerald-700 ring-emerald-600/20",
  sent: "bg-amber-50 text-amber-700 ring-amber-600/20",
  draft: "bg-secondary text-muted-foreground ring-border",
  void: "bg-muted text-muted-foreground ring-border line-through",
};

const STATUS_LABEL: Record<InvoiceStatus, string> = {
  paid: "Paid",
  sent: "Sent",
  draft: "Draft",
  void: "Void",
};

function formatAmount(cents: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(cents / 100);
}

function shortId(id: string): string {
  return `INV-${id.slice(0, 8).toUpperCase()}`;
}

export function InvoicesTable({ invoices }: { invoices: Invoice[] }) {
  if (invoices.length === 0) {
    return (
      <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed border-border py-16 text-center">
        <Receipt className="h-8 w-8 text-muted-foreground/40" />
        <div>
          <p className="text-body font-medium text-foreground">No invoices yet</p>
          <p className="mt-1 text-body text-muted-foreground">
            Fixed-rate and commission billing are generated automatically on report delivery.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="overflow-x-auto rounded-lg border border-border">
      <table className="w-full text-body" aria-label="Invoices">
        <thead>
          <tr className="border-b border-border bg-muted/40">
            <th className="px-4 py-3 text-left font-medium text-muted-foreground">Invoice</th>
            <th className="px-4 py-3 text-left font-medium text-muted-foreground">Mode</th>
            <th className="px-4 py-3 text-right font-medium text-muted-foreground">Amount</th>
            <th className="px-4 py-3 text-left font-medium text-muted-foreground">Status</th>
          </tr>
        </thead>
        <tbody>
          {invoices.map((invoice, i) => (
            <tr
              key={invoice.id}
              className={cn(i > 0 && "border-t border-border")}
            >
              <td className="px-4 py-3 font-mono text-mono-sm text-muted-foreground">
                {shortId(invoice.id)}
              </td>
              <td className="px-4 py-3">
                {BILLING_LABEL[invoice.billing_mode] ?? invoice.billing_mode}
              </td>
              <td className="px-4 py-3 text-right tabular-nums">
                {formatAmount(invoice.amount_cents)}
              </td>
              <td className="px-4 py-3">
                <span
                  className={cn(
                    "inline-flex items-center rounded-full px-2 py-0.5 text-label font-medium ring-1 ring-inset",
                    STATUS_PILL[invoice.status],
                  )}
                >
                  {STATUS_LABEL[invoice.status]}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
