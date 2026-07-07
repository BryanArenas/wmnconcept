import { cn } from "@/lib/utils";

// Brand mark (§7): a 22px red square with an 8px black inner square, centered.
export function BrandMark({ className }: { className?: string }) {
  return (
    <span
      aria-hidden
      className={cn(
        "inline-flex size-[22px] items-center justify-center rounded-[3px] bg-primary",
        className,
      )}
    >
      <span className="size-2 bg-foreground" />
    </span>
  );
}
