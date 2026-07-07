import { cookies } from "next/headers";
import { PageHeader } from "@/components/domain/page-header";
import { DispatchBoard } from "@/components/domain/dispatch-board";
import { apiFetch } from "@/lib/api";
import type { Inspection, Paginated, StaffUser } from "@/lib/types";

// Coordinator — Dispatch (§8.8). Fetches unassigned + assigned inspections and
// the inspector roster server-side, then hands off to the DispatchBoard client
// component for assign + schedule interactions.
export default async function DispatchPage() {
  const cookieStore = await cookies();
  const cookieHeader = cookieStore.toString();

  const [inspectionsResult, usersResult] = await Promise.all([
    apiFetch<Paginated<Inspection>>(
      "/api/v1/inspections?status=unassigned",
      { headers: { cookie: cookieHeader }, cache: "no-store" },
    ).catch(() => ({ data: [] as Inspection[], meta: { next_cursor: null } })),

    apiFetch<Paginated<StaffUser>>(
      "/api/v1/users?role=inspector",
      { headers: { cookie: cookieHeader }, cache: "no-store" },
    ).catch(() => ({ data: [] as StaffUser[], meta: { next_cursor: null } })),
  ]);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Operations"
        title="Dispatch"
        description="Assign inspectors and schedule visits. Adding a datetime fires the T-24h reminder automatically."
      />
      <DispatchBoard
        initialInspections={inspectionsResult.data}
        inspectors={usersResult.data}
      />
    </div>
  );
}
