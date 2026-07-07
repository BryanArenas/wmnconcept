import { cookies } from "next/headers";
import { PageHeader } from "@/components/domain/page-header";
import { InvoicesTable } from "@/components/domain/invoices-table";
import { apiFetch } from "@/lib/api";
import type { Invoice, Paginated } from "@/lib/types";

// Agency — Invoices (§8.5). Read-only billing history, scoped server-side to the
// signed-in agency. Billing is generated automatically on report delivery (M6);
// Stripe send/collect is staff-driven (M7).
export default async function AgencyInvoicesPage() {
  const cookieStore = await cookies();
  const cookieHeader = cookieStore.toString();

  const result = await apiFetch<Paginated<Invoice>>(
    "/api/v1/invoices?limit=100",
    { headers: { cookie: cookieHeader }, cache: "no-store" },
  ).catch(() => ({ data: [] as Invoice[], meta: { next_cursor: null } }));

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Agency portal"
        title="Invoices"
        description="Fixed-rate and commission billing are generated automatically on report delivery."
      />
      <InvoicesTable invoices={result.data} />
    </div>
  );
}
