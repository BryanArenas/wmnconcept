import { PageHeader } from "@/components/domain/page-header";
import { EmptyState } from "@/components/domain/empty-state";

// Coordinator — Calendar (§8.10). Week view / grouped list lands in M4.
export default function CalendarPage() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Schedule"
        title="Calendar"
        description="Scheduled inspections by day and inspector."
      />
      <EmptyState
        title="Nothing scheduled yet."
        description="The calendar (week view, list fallback acceptable) arrives in M4."
      />
    </div>
  );
}
