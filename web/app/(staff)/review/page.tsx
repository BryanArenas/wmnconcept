import { PageHeader } from "@/components/domain/page-header";
import { EmptyState } from "@/components/domain/empty-state";

// Manager — Review queue (§8.13). Approve/reject → delivery pipeline lands in M6.
export default function ReviewPage() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Quality gate"
        title="Review queue"
        description="Approve to generate the PDF, deliver to homeowner and agency, and create the invoice — or send back with a note."
      />
      <EmptyState
        title="Nothing awaiting review."
        description="The review queue and the approve → deliver → invoice pipeline arrive in M6."
      />
    </div>
  );
}
