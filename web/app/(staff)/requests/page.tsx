import { PageHeader } from "@/components/domain/page-header";
import { EmptyState } from "@/components/domain/empty-state";

// Coordinator — Requests triage (§8.7). Accept/decline lands in M3.
export default function RequestsPage() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Triage"
        title="Requests"
        description="Accept an agency request to spawn one inspection per type, or decline with a reason."
      />
      <EmptyState
        title="No pending requests."
        description="New agency submissions land here. Intake and accept/decline arrive in M3."
      />
    </div>
  );
}
