import { cookies } from "next/headers";
import { PageHeader } from "@/components/domain/page-header";
import { RequestsTriage } from "@/components/domain/requests-triage";
import { apiFetch } from "@/lib/api";
import type { InspectionRequest, InspectionTypeConfig, Paginated } from "@/lib/types";

// Coordinator — Requests triage (§8.7). Fetches submitted requests and the
// price config list (for label + price chips on each card) server-side.
export default async function RequestsPage() {
  const cookieStore = await cookies();
  const cookieHeader = cookieStore.toString();

  const [requestsResult, configsResult] = await Promise.all([
    apiFetch<Paginated<InspectionRequest>>(
      "/api/v1/inspection_requests?status=submitted",
      { headers: { cookie: cookieHeader }, cache: "no-store" },
    ).catch(() => ({ data: [] as InspectionRequest[], meta: { next_cursor: null } })),

    apiFetch<{ data: InspectionTypeConfig[] }>("/api/v1/inspection_type_configs", {
      headers: { cookie: cookieHeader },
      cache: "no-store",
    }).catch(() => ({ data: [] as InspectionTypeConfig[] })),
  ]);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Triage"
        title="Requests"
        description="Accept an agency request to spawn one inspection per type, or decline with a reason."
      />
      <RequestsTriage
        initialRequests={requestsResult.data}
        configs={configsResult.data}
      />
    </div>
  );
}
