"use client";

import * as React from "react";
import { Info } from "lucide-react";
import { cn } from "@/lib/utils";

// Small info affordance: an icon that reveals a short explanation on hover or
// focus, so we can keep helper/tutorial prose out of the main layout. Keep the
// content to a sentence or two.
export function InfoHint({
  children,
  label = "More information",
  side = "bottom",
  className,
}: {
  children: React.ReactNode;
  label?: string;
  side?: "top" | "bottom";
  className?: string;
}) {
  const [open, setOpen] = React.useState(false);

  return (
    <span className={cn("relative inline-flex align-middle", className)}>
      <button
        type="button"
        aria-label={label}
        className="inline-flex rounded-full text-muted-foreground/70 transition-colors hover:text-foreground focus:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        onMouseEnter={() => setOpen(true)}
        onMouseLeave={() => setOpen(false)}
        onFocus={() => setOpen(true)}
        onBlur={() => setOpen(false)}
        onClick={(e) => {
          e.preventDefault();
          setOpen((v) => !v);
        }}
      >
        <Info className="h-3.5 w-3.5" />
      </button>
      {open && (
        <span
          role="tooltip"
          className={cn(
            "absolute left-1/2 z-50 w-max max-w-[260px] -translate-x-1/2 rounded-md border border-border bg-popover px-2.5 py-1.5 text-label font-normal leading-snug text-muted-foreground shadow-md",
            side === "bottom" ? "top-full mt-1.5" : "bottom-full mb-1.5",
          )}
        >
          {children}
        </span>
      )}
    </span>
  );
}
