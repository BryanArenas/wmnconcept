"use client";

import { useEffect } from "react";
import { AlertTriangle, RotateCcw } from "lucide-react";
import { Button } from "@/components/ui/button";

export function ErrorPanel({
  error,
  retry,
}: {
  error: Error & { digest?: string };
  retry: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div
      role="alert"
      className="flex flex-col items-center gap-4 rounded-lg border border-dashed border-destructive/40 py-16 text-center"
    >
      <AlertTriangle className="h-8 w-8 text-destructive/60" />
      <div className="flex flex-col gap-1">
        <p className="text-title text-foreground">Something went wrong</p>
        <p className="max-w-[42ch] text-body text-muted-foreground">
          The page could not load. This is usually temporary — try refreshing.
        </p>
        {error.digest && (
          <p className="mt-1 font-mono text-label text-muted-foreground/60">
            {error.digest}
          </p>
        )}
      </div>
      <Button variant="outline" size="sm" onClick={retry}>
        <RotateCcw className="mr-1.5 h-3.5 w-3.5" />
        Try again
      </Button>
    </div>
  );
}
