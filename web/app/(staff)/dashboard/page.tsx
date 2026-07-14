import { cookies } from "next/headers";
import { requireRole } from "@/lib/auth";
import { PageHeader } from "@/components/domain/page-header";
import { StatCard } from "@/components/domain/stat-card";
import { EmptyState } from "@/components/domain/empty-state";
import { RecentActivity } from "@/components/domain/recent-activity";
import { apiFetch } from "@/lib/api";
import type { DashboardData } from "@/lib/types";

export default async function StaffDashboardPage() {
  const user = await requireRole("org_admin", "coordinator", "manager");
  const cookieStore = await cookies();
  const cookieHeader = cookieStore.toString();

  const dashboard = await apiFetch<DashboardData>("/api/v1/dashboard", {
    headers: { cookie: cookieHeader },
    cache: "no-store",
  }).catch(() => null);

  const stats = dashboard?.stats;

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow={user.organization?.name ?? "Wind Mitigation Network"}
        title="Dashboard"
        description="Triage new requests, dispatch inspectors, and keep every inspection moving toward the 24-hour delivery promise."
      />

      {/* Each card feeds a screen: Requests → Dispatch → Calendar → Review. */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Pending requests"
          value={stats ? String(stats.pending_requests) : "—"}
          hint="Awaiting triage"
        />
        <StatCard
          label="Unassigned"
          value={stats ? String(stats.unassigned) : "—"}
          hint="Need an inspector"
        />
        <StatCard
          label="Scheduled"
          value={stats ? String(stats.scheduled) : "—"}
          hint="On the calendar"
        />
        <StatCard
          label="Awaiting review"
          value={stats ? String(stats.awaiting_review) : "—"}
          hint="Quality gate"
        />
      </div>

      {dashboard === null ? (
        <EmptyState
          title="Could not load dashboard stats."
          description="The API may be unreachable. Try refreshing the page."
        />
      ) : (
        <section className="flex flex-col gap-3">
          <h2 className="text-title text-foreground">Recent activity</h2>
          <RecentActivity events={dashboard.activity} />
        </section>
      )}
    </div>
  );
}
