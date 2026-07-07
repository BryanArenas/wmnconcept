import { cn } from "@/lib/utils";

function Bone({ className }: { className?: string }) {
  return (
    <div
      className={cn(
        "animate-pulse rounded-md bg-muted",
        className,
      )}
    />
  );
}

export function PageSkeleton({ variant = "list" }: { variant?: "list" | "cards" | "table" }) {
  return (
    <div className="flex flex-col gap-6">
      {/* Header skeleton */}
      <div className="flex flex-col gap-3 border-b border-border pb-5">
        <Bone className="h-3 w-24" />
        <Bone className="h-8 w-48" />
        <Bone className="h-4 w-80" />
      </div>

      {variant === "table" && <TableSkeleton />}
      {variant === "cards" && <CardsSkeleton />}
      {variant === "list" && <CardsSkeleton />}
    </div>
  );
}

function CardsSkeleton() {
  return (
    <div className="flex flex-col gap-3">
      {Array.from({ length: 3 }, (_, i) => (
        <div key={i} className="rounded-lg border border-border p-5">
          <div className="flex items-start justify-between gap-4">
            <div className="flex flex-col gap-2">
              <Bone className="h-4 w-32" />
              <Bone className="h-3.5 w-56" />
              <Bone className="h-3 w-40" />
            </div>
            <Bone className="h-8 w-20" />
          </div>
        </div>
      ))}
    </div>
  );
}

function TableSkeleton() {
  return (
    <div className="overflow-x-auto rounded-lg border border-border">
      <div className="border-b border-border bg-muted/40 px-4 py-3">
        <div className="flex gap-12">
          <Bone className="h-3.5 w-16" />
          <Bone className="h-3.5 w-12" />
          <Bone className="h-3.5 w-14" />
          <Bone className="h-3.5 w-20" />
        </div>
      </div>
      {Array.from({ length: 4 }, (_, i) => (
        <div key={i} className="border-b border-border px-4 py-3 last:border-b-0">
          <div className="flex gap-12">
            <Bone className="h-3.5 w-28" />
            <Bone className="h-3.5 w-16" />
            <Bone className="h-3.5 w-16" />
            <Bone className="h-3.5 w-32" />
          </div>
        </div>
      ))}
    </div>
  );
}

export function StatsSkeleton() {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
      {Array.from({ length: 3 }, (_, i) => (
        <div key={i} className="rounded-lg border border-border px-5 py-4">
          <Bone className="h-3 w-24" />
          <Bone className="mt-3 h-8 w-12" />
          <Bone className="mt-2 h-3 w-32" />
        </div>
      ))}
    </div>
  );
}
