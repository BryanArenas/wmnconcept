import { cookies } from "next/headers";
import Link from "next/link";
import { PageHeader } from "@/components/domain/page-header";
import { StatCard } from "@/components/domain/stat-card";
import { EmptyState } from "@/components/domain/empty-state";
import { Button } from "@/components/ui/button";
import { apiFetch } from "@/lib/api";
import type { Invoice, Paginated } from "@/lib/types";

export default async function AgencyDashboardPage() {
  const cookieStore = await cookies();
  const cookieHeader = cookieStore.toString();
  const opts = { headers: { cookie: cookieHeader }, cache: "no-store" as const };

  const invoices = await apiFetch<Paginated<Invoice>>("/api/v1/invoices?limit=100", opts)
    .catch(() => null);

  const total = invoices?.data.length ?? 0;
  const paid = invoices?.data.filter((i) => i.status === "paid").length ?? 0;
  const outstanding = invoices?.data.filter((i) => i.status === "sent").length ?? 0;

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Agency portal"
        title="Dashboard"
        description="Request an inspection and the office handles assignment, scheduling, and delivery. No phone calls."
      />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatCard label="Total invoices" value={invoices ? String(total) : "—"} />
        <StatCard label="Paid" value={invoices ? String(paid) : "—"} />
        <StatCard label="Outstanding" value={invoices ? String(outstanding) : "—"} />
      </div>

      {total === 0 && (
        <EmptyState
          title="No inspections yet."
          description="Request your first — reports usually arrive within 24 hours."
          action={
            <Button asChild>
              <Link href="/agency/request/new">Request inspection</Link>
            </Button>
          }
        />
      )}
    </div>
  );
}
