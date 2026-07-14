import { cookies } from "next/headers";
import { PageHeader } from "@/components/domain/page-header";
import { AgenciesTable } from "@/components/domain/agencies-table";
import { getCurrentUser } from "@/lib/auth";
import { apiFetch } from "@/lib/api";
import type { Agency, Paginated } from "@/lib/types";

// Fetches the first page of agencies server-side (session cookie forwarded).
// org_admin sees the "Add agency" button; coordinators/managers see read-only.
export default async function AgenciesPage() {
  const cookieStore = await cookies();
  const cookieHeader = cookieStore.toString();

  const [user, result] = await Promise.all([
    getCurrentUser(),
    apiFetch<Paginated<Agency>>("/api/v1/agencies", {
      headers: { cookie: cookieHeader },
      cache: "no-store",
    }).catch(() => ({ data: [] as Agency[], meta: { next_cursor: null } })),
  ]);

  const canCreate = user?.role === "org_admin" || user?.role === "coordinator";

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Partners"
        title="Agencies"
        description="Manage referral partners and their portal logins. Billing mode is set per agency."
      />
      <AgenciesTable initialAgencies={result.data} canCreate={canCreate} />
    </div>
  );
}
