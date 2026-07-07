import { cookies } from "next/headers";
import { requireRole } from "@/lib/auth";
import { PageHeader } from "@/components/domain/page-header";
import { FieldQueue } from "@/components/domain/field-queue";
import { apiFetch } from "@/lib/api";
import type { Inspection, Paginated } from "@/lib/types";

// Inspector — Today (§8.11). Fetches the inspector's own scheduled + in_progress
// inspections (scope gates server-side to assigned_inspector_id == current user).
export default async function TodayPage() {
  const user = await requireRole("inspector");
  const cookieStore = await cookies();
  const cookieHeader = cookieStore.toString();

  const [scheduledResult, inProgressResult] = await Promise.all([
    apiFetch<Paginated<Inspection>>(
      "/api/v1/inspections?status=scheduled&limit=50",
      { headers: { cookie: cookieHeader }, cache: "no-store" },
    ).catch(() => ({ data: [] as Inspection[], meta: { next_cursor: null } })),

    apiFetch<Paginated<Inspection>>(
      "/api/v1/inspections?status=in_progress&limit=50",
      { headers: { cookie: cookieHeader }, cache: "no-store" },
    ).catch(() => ({ data: [] as Inspection[], meta: { next_cursor: null } })),
  ]);

  const inspections = [
    ...inProgressResult.data,
    ...scheduledResult.data,
  ];

  const license = user.license_number ? ` · ${user.license_number}` : "";

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow={`${user.name}${license}`}
        title="Today"
        description="Your assigned inspections. Start on site, capture the form and photos, then submit for review."
      />
      <FieldQueue initialInspections={inspections} />
    </div>
  );
}
