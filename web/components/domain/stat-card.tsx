import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";

// Dashboard stat tile (§8): eyebrow label + large serif number. Bordered card,
// no shadow. `value` is a string so callers can show "—" before data lands.
export function StatCard({
  label,
  value,
  hint,
  className,
}: {
  label: string;
  value: string;
  hint?: string;
  className?: string;
}) {
  return (
    <Card className={cn("px-5 py-4", className)}>
      <p className="text-eyebrow uppercase text-muted-foreground">{label}</p>
      <p className="mt-2 font-serif text-stat text-foreground tabular-nums">
        {value}
      </p>
      {hint && <p className="mt-1 text-body text-muted-foreground">{hint}</p>}
    </Card>
  );
}
