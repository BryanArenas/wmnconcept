import { PageSkeleton, StatsSkeleton } from "@/components/domain/page-skeleton";

export default function StaffLoading() {
  return (
    <div className="flex flex-col gap-6">
      <StatsSkeleton />
      <PageSkeleton variant="cards" />
    </div>
  );
}
