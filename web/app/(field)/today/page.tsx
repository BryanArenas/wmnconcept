import { requireRole } from "@/lib/auth";
import { PageHeader } from "@/components/domain/page-header";
import { EmptyState } from "@/components/domain/empty-state";

// Inspector — Today (§8.11): the assigned queue. Field capture lands in M5.
export default async function TodayPage() {
  const user = await requireRole("inspector");
  const license = user.license_number ? ` · ${user.license_number}` : "";

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow={`${user.name}${license}`}
        title="Today"
        description="Your assigned inspections. Start on site, capture the form and photos, then submit for review."
      />
      <EmptyState
        title="No assigned inspections."
        description="New assignments appear here. The field capture flow (start → form → photos → submit) arrives in M5."
      />
    </div>
  );
}
