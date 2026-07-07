import { PageHeader } from "@/components/domain/page-header";
import { StatCard } from "@/components/domain/stat-card";
import { EmptyState } from "@/components/domain/empty-state";

// Agency — Dashboard (§8.1). The partner wedge: at-a-glance status + one-tap
// request. Agency auth + live data land in M2–M3.
export default function AgencyDashboardPage() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Agency portal"
        title="Dashboard"
        description="Request an inspection and the office handles assignment, scheduling, and delivery. No phone calls."
      />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatCard label="Open inspections" value="—" />
        <StatCard label="Delivered all-time" value="—" />
        <StatCard label="Reports this week" value="—" />
      </div>

      <EmptyState
        title="No inspections yet."
        description="Request your first — reports usually arrive within 24 hours. The agency portal goes live in M2–M3."
      />
    </div>
  );
}
