import { cn } from "@/lib/utils";

// PageHeader (§8): eyebrow + serif title on the left, optional single CTA on the
// right. The CTA is the screen's one bg-primary element (§5.1) — pass a Button
// with the default variant.
export function PageHeader({
  eyebrow,
  title,
  description,
  action,
  className,
}: {
  eyebrow?: string;
  title: string;
  description?: string;
  action?: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex flex-col gap-3 border-b border-border pb-5 sm:flex-row sm:items-end sm:justify-between",
        className,
      )}
    >
      <div className="flex flex-col gap-1.5">
        {eyebrow && (
          <span className="text-eyebrow uppercase text-muted-foreground">
            {eyebrow}
          </span>
        )}
        <h1 className="font-serif text-display-lg text-foreground">{title}</h1>
        {description && (
          <p className="max-w-[62ch] text-body text-muted-foreground">
            {description}
          </p>
        )}
      </div>
      {action && <div className="shrink-0">{action}</div>}
    </div>
  );
}
