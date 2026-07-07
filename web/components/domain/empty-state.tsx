import { cn } from "@/lib/utils";

// Quiet, editorial empty state (§8). Copy carries the reassurance ("reports
// usually arrive within 24 hours"); an optional action follows.
export function EmptyState({
  title,
  description,
  action,
  className,
}: {
  title: string;
  description?: string;
  action?: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex flex-col items-start gap-3 rounded-lg border border-dashed border-border px-6 py-10",
        className,
      )}
    >
      <p className="text-title text-foreground">{title}</p>
      {description && (
        <p className="max-w-[52ch] text-body text-muted-foreground">
          {description}
        </p>
      )}
      {action && <div className="pt-1">{action}</div>}
    </div>
  );
}
