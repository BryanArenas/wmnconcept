import { PageHeader } from "@/components/domain/page-header";
import { EmptyState } from "@/components/domain/empty-state";

// Coordinator — Dispatch (§8.8). Assign + schedule lands in M4.
export default function DispatchPage() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Operations"
        title="Dispatch"
        description="Assign inspectors and schedule visits. Adding a datetime fires the T-24h reminder."
      />
      <EmptyState
        title="Nothing to dispatch right now."
        description="Assignment and scheduling arrive in M4, driven by the §6 status machine."
      />
    </div>
  );
}
