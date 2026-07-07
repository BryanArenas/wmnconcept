import { cookies } from "next/headers";
import { PageHeader } from "@/components/domain/page-header";
import { CalendarView } from "@/components/domain/calendar-view";
import { apiFetch } from "@/lib/api";
import type { Inspection, Paginated } from "@/lib/types";

// Coordinator — Calendar (§8.10). All scheduled inspections grouped by day.
// Uses the inspections?status=scheduled filter; CalendarView re-sorts by
// scheduled_at client-side for correct chronological display.
export default async function CalendarPage() {
  const cookieStore = await cookies();
  const cookieHeader = cookieStore.toString();

  const result = await apiFetch<Paginated<Inspection>>(
    "/api/v1/inspections?status=scheduled&limit=100",
    { headers: { cookie: cookieHeader }, cache: "no-store" },
  ).catch(() => ({ data: [] as Inspection[], meta: { next_cursor: null } }));

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Operations"
        title="Calendar"
        description="Scheduled inspections grouped by day. Assign and schedule from the Dispatch screen."
      />
      <CalendarView inspections={result.data} />
    </div>
  );
}
