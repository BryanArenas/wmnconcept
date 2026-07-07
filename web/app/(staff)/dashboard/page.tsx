import { requireRole } from "@/lib/auth";
import { PageHeader } from "@/components/domain/page-header";
import { StatCard } from "@/components/domain/stat-card";
import { EmptyState } from "@/components/domain/empty-state";

// Coordinator dashboard (§8.6). Stats + active inspections wire up in M3–M4
// against the /dashboard endpoint; M1 ships the shell with resting states.
export default async function StaffDashboardPage() {
  const user = await requireRole("org_admin", "coordinator", "manager");

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow={user.organization?.name ?? "Wind Mitigation Network"}
        title="Dashboard"
        description="Triage new requests, dispatch inspectors, and keep every inspection moving toward the 24-hour delivery promise."
      />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatCard label="Pending requests" value="—" hint="Awaiting triage" />
        <StatCard label="Awaiting assignment" value="—" hint="Unassigned inspections" />
        <StatCard label="Active inspections" value="—" hint="In flight now" />
      </div>

      <EmptyState
        title="Live operations land in the next milestones."
        description="Request intake and triage arrive in M3; assignment, scheduling, and the calendar in M4. The shell, auth, and tenancy are in place now."
      />
    </div>
  );
}
