import { cookies } from "next/headers";
import { PageHeader } from "@/components/domain/page-header";
import { InspectionRequestForm } from "@/components/domain/inspection-request-form";
import { apiFetch } from "@/lib/api";
import type { InspectionTypeConfig } from "@/lib/types";

// Agency — submit inspection request (§8.2). Fetches price configs server-side
// so type chips render immediately with correct labels and prices (PLACEHOLDER
// data until the confirmed price sheet arrives — spec §11).
export default async function NewRequestPage() {
  const cookieStore = await cookies();
  const cookieHeader = cookieStore.toString();

  const configs = await apiFetch<{ data: InspectionTypeConfig[] }>(
    "/api/v1/inspection_type_configs",
    { headers: { cookie: cookieHeader }, cache: "no-store" },
  )
    .then((r) => r.data)
    .catch(() => [] as InspectionTypeConfig[]);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Agency portal"
        title="Request an inspection"
        description="Select the inspection types you need. An inspector will be assigned and scheduled within one business day."
      />
      <InspectionRequestForm configs={configs} />
    </div>
  );
}
