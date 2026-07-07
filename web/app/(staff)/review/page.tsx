import { cookies } from "next/headers";
import { PageHeader } from "@/components/domain/page-header";
import { ReviewBoard } from "@/components/domain/review-board";
import { apiFetch } from "@/lib/api";
import type { Inspection, Paginated } from "@/lib/types";

// Manager — Review queue (§8.13). Fetches inspections awaiting review plus the
// last few delivered, then hands off to the ReviewBoard client component for
// approve/reject. Approve fires the report → deliver → invoice pipeline (§9).
export default async function ReviewPage() {
  const cookieStore = await cookies();
  const cookieHeader = cookieStore.toString();

  const [queueResult, deliveredResult] = await Promise.all([
    apiFetch<Paginated<Inspection>>(
      "/api/v1/inspections?status=submitted_for_review&limit=100",
      { headers: { cookie: cookieHeader }, cache: "no-store" },
    ).catch(() => ({ data: [] as Inspection[], meta: { next_cursor: null } })),

    apiFetch<Paginated<Inspection>>(
      "/api/v1/inspections?status=delivered&limit=3",
      { headers: { cookie: cookieHeader }, cache: "no-store" },
    ).catch(() => ({ data: [] as Inspection[], meta: { next_cursor: null } })),
  ]);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="Quality gate"
        title="Review queue"
        description="Approve to generate the PDF, deliver to homeowner and agency, and create the invoice — or send back with a note."
      />
      <ReviewBoard
        initialQueue={queueResult.data}
        recentlyDelivered={deliveredResult.data}
      />
    </div>
  );
}
