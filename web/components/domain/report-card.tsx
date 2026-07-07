"use client";

import * as React from "react";
import { FileText, Download, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { apiFetch, ApiError, API_BASE_URL } from "@/lib/api";
import type { Report } from "@/lib/types";

interface Props {
  inspectionId: string;
  filename?: string | null;
  deliveredAt?: string | null;
}

// The delivered-report card (§8.4). Shown only once a report exists. The signed
// download URL is short-lived, so it is fetched lazily on click rather than
// baked into the page.
export function ReportCard({ inspectionId, filename, deliveredAt }: Props) {
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  async function handleDownload() {
    setLoading(true);
    setError(null);
    try {
      const { data } = await apiFetch<{ data: Report }>(
        `/api/v1/inspections/${inspectionId}/report`,
      );
      if (!data.download_url) throw new Error("No download URL");
      // Relative URLs (local-storage fallback) resolve against the API host;
      // absolute S3 presigned URLs are used as-is.
      const url = data.download_url.startsWith("http")
        ? data.download_url
        : `${API_BASE_URL}${data.download_url}`;
      window.open(url, "_blank", "noopener,noreferrer");
    } catch (err) {
      setError(
        err instanceof ApiError ? err.message : "Could not fetch the report.",
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="rounded-lg border border-border bg-card p-5">
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-start gap-3">
          <div className="mt-0.5 flex size-9 shrink-0 items-center justify-center rounded-md bg-secondary">
            <FileText className="h-4 w-4 text-muted-foreground" />
          </div>
          <div className="flex flex-col gap-0.5">
            <p className="text-sm font-medium">Report delivered</p>
            <p className="font-mono text-label text-muted-foreground">
              {filename ?? "wmn-report.pdf"}
            </p>
            {deliveredAt && (
              <p className="text-label text-muted-foreground">
                {new Intl.DateTimeFormat("en-US", {
                  month: "short", day: "numeric", year: "numeric",
                  hour: "numeric", minute: "2-digit",
                }).format(new Date(deliveredAt))}
              </p>
            )}
          </div>
        </div>

        <Button size="sm" variant="outline" onClick={handleDownload} disabled={loading}>
          {loading ? (
            <Loader2 className="h-3.5 w-3.5 animate-spin" />
          ) : (
            <Download className="h-3.5 w-3.5" />
          )}
          Download
        </Button>
      </div>
      {error && <p className="mt-3 text-label text-destructive">{error}</p>}
    </div>
  );
}
