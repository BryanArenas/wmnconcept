import * as React from "react";

import { cn } from "@/lib/utils";

// Plain hairline rule (§5.3). Radix's separator isn't needed for a decorative
// 1px line; kept dependency-free.
function Separator({
  className,
  orientation = "horizontal",
  ...props
}: React.ComponentProps<"div"> & { orientation?: "horizontal" | "vertical" }) {
  return (
    <div
      data-slot="separator"
      role="none"
      className={cn(
        "shrink-0 bg-border",
        orientation === "horizontal" ? "h-px w-full" : "h-full w-px",
        className,
      )}
      {...props}
    />
  );
}

export { Separator };
