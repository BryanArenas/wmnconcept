import { INSPECTION_STATUS } from "@/lib/status";
import type { InspectionStatus } from "@/lib/types";
import { cn } from "@/lib/utils";

// Status = a single colored dot + label (§5.1), never a filled row. The dot hex
// comes from the §5.1 status palette via the status map.
export function StatusDot({
  status,
  className,
  showLabel = true,
}: {
  status: InspectionStatus;
  className?: string;
  showLabel?: boolean;
}) {
  const meta = INSPECTION_STATUS[status];

  return (
    <span className={cn("inline-flex items-center gap-2", className)}>
      <span
        className="size-2 shrink-0 rounded-full"
        style={{ backgroundColor: meta.color }}
        aria-hidden
      />
      {showLabel ? (
        <span className="text-body text-muted-foreground">{meta.label}</span>
      ) : (
        <span className="sr-only">{meta.label}</span>
      )}
    </span>
  );
}
