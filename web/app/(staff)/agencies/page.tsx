import { PageHeader } from "@/components/domain/page-header";
import { EmptyState } from "@/components/domain/empty-state";

// Coordinator — Agencies (§8.9, org_admin). Onboarding + invites land in M2.
export default function AgenciesPage() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Partners"
        title="Agencies"
        description="Onboard referral partners and invite their first user. Billing mode is set per agency."
      />
      <EmptyState
        title="No agencies yet."
        description="Agency onboarding and invites arrive in M2."
      />
    </div>
  );
}
