import { cookies } from "next/headers";
import { requireRole } from "@/lib/auth";
import { PageHeader } from "@/components/domain/page-header";
import { StatCard } from "@/components/domain/stat-card";
import { EmptyState } from "@/components/domain/empty-state";
import { apiFetch } from "@/lib/api";
import type { InspectionRequest, Inspection, Paginated } from "@/lib/types";

export default async function StaffDashboardPage() {
  const user = await requireRole("org_admin", "coordinator", "manager");
  const cookieStore = await cookies();
  const cookieHeader = cookieStore.toString();
  const opts = { headers: { cookie: cookieHeader }, cache: "no-store" as const };

  const [requests, unassigned, inFlight, review] = await Promise.all([
    apiFetch<Paginated<InspectionRequest>>("/api/v1/inspection_requests?status=submitted&limit=1", opts)
      .catch(() => null),
    apiFetch<Paginated<Inspection>>("/api/v1/inspections?status=unassigned&limit=1", opts)
      .catch(() => null),
    apiFetch<Paginated<Inspection>>("/api/v1/inspections?status=in_progress&limit=1", opts)
      .catch(() => null),
    apiFetch<Paginated<Inspection>>("/api/v1/inspections?status=submitted_for_review&limit=1", opts)
      .catch(() => null),
  ]);

  const allNull = [requests, unassigned, inFlight, review].every((r) => r === null);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow={user.organization?.name ?? "Wind Mitigation Network"}
        title="Dashboard"
        description="Triage new requests, dispatch inspectors, and keep every inspection moving toward the 24-hour delivery promise."
      />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Pending requests"
          value={requests ? String(requests.data.length) : "—"}
          hint="Awaiting triage"
        />
        <StatCard
          label="Unassigned"
          value={unassigned ? String(unassigned.data.length) : "—"}
          hint="Need an inspector"
        />
        <StatCard
          label="In the field"
          value={inFlight ? String(inFlight.data.length) : "—"}
          hint="Active inspections"
        />
        <StatCard
          label="Awaiting review"
          value={review ? String(review.data.length) : "—"}
          hint="Quality gate"
        />
      </div>

      {allNull && (
        <EmptyState
          title="Could not load dashboard stats."
          description="The API may be unreachable. Try refreshing the page."
        />
      )}
    </div>
  );
}
