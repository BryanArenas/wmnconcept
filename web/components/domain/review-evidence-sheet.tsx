"use client";

import * as React from "react";
import { ImageIcon, Send, Loader2 } from "lucide-react";

import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { apiFetch, ApiError } from "@/lib/api";
import type { Inspection, InspectionEvidence } from "@/lib/types";

function answerText(value: string | number | boolean | string[] | undefined): string {
  if (value === undefined || value === null || value === "") return "—";
  if (Array.isArray(value)) return value.length ? value.join(", ") : "—";
  if (value === true) return "Yes";
  if (value === false) return "No";
  return String(value);
}

interface Props {
  inspection: Inspection | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  approved: boolean;
  onApprove: () => void;
  onReject: () => void;
}

// Side pane that shows what an inspector captured — form answers + photos — so a
// reviewer can actually review before approving. Loads on open.
export function ReviewEvidenceSheet({
  inspection,
  open,
  onOpenChange,
  approved,
  onApprove,
  onReject,
}: Props) {
  const [evidence, setEvidence] = React.useState<InspectionEvidence | null>(null);
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    if (!open || !inspection) return;
    setLoading(true);
    setError(null);
    setEvidence(null);
    apiFetch<InspectionEvidence>(`/api/v1/inspections/${inspection.id}/evidence`)
      .then(setEvidence)
      .catch((err) =>
        setError(err instanceof ApiError ? err.message : "Could not load evidence."),
      )
      .finally(() => setLoading(false));
  }, [open, inspection]);

  const typeLabel = inspection?.inspection_type
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="max-w-lg overflow-y-auto">
        <SheetHeader>
          <SheetTitle>Review evidence</SheetTitle>
          {inspection && (
            <SheetDescription>
              {typeLabel} · {inspection.property_address}
            </SheetDescription>
          )}
        </SheetHeader>

        {inspection && (
          <p className="text-label text-muted-foreground">
            {inspection.homeowner_name} · {inspection.agency_name}
            {inspection.assigned_inspector_name
              ? ` · Inspector: ${inspection.assigned_inspector_name}`
              : ""}
          </p>
        )}

        <div className="flex-1 overflow-y-auto">
          {loading && (
            <div className="flex items-center gap-2 py-8 text-body text-muted-foreground">
              <Loader2 className="h-4 w-4 animate-spin" /> Loading captured evidence…
            </div>
          )}

          {error && (
            <p role="alert" className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-body text-destructive">
              {error}
            </p>
          )}

          {evidence && !loading && (
            <div className="flex flex-col gap-6 py-2">
              <section className="flex flex-col gap-2">
                <h3 className="text-label font-semibold uppercase tracking-wide text-muted-foreground">
                  Inspection findings
                </h3>
                {evidence.form.fields.length === 0 ? (
                  <p className="text-body text-muted-foreground">
                    No form template configured for this type.
                  </p>
                ) : (
                  <dl className="overflow-hidden rounded-lg border border-border">
                    {evidence.form.fields.map((field, i) => (
                      <div
                        key={field.key}
                        className={
                          "grid grid-cols-[1fr_1fr] gap-3 px-3 py-2 text-body " +
                          (i % 2 ? "bg-muted/40" : "")
                        }
                      >
                        <dt className="text-muted-foreground">{field.label}</dt>
                        <dd className="font-medium text-foreground">
                          {answerText(evidence.form.responses[field.key])}
                        </dd>
                      </div>
                    ))}
                  </dl>
                )}
              </section>

              <section className="flex flex-col gap-2">
                <h3 className="text-label font-semibold uppercase tracking-wide text-muted-foreground">
                  Photos ({evidence.photos.length})
                </h3>
                {evidence.photos.length === 0 ? (
                  <p className="text-body text-muted-foreground">No photos uploaded.</p>
                ) : (
                  <div className="grid grid-cols-2 gap-2">
                    {evidence.photos.map((photo) =>
                      photo.view_url ? (
                        <a
                          key={photo.id}
                          href={photo.view_url}
                          target="_blank"
                          rel="noreferrer"
                          className="group relative overflow-hidden rounded-md border border-border"
                        >
                          {/* eslint-disable-next-line @next/next/no-img-element */}
                          <img
                            src={photo.view_url}
                            alt={photo.filename ?? "Inspection photo"}
                            className="aspect-square w-full object-cover"
                          />
                        </a>
                      ) : (
                        <div
                          key={photo.id}
                          className="flex items-center gap-2 rounded-md border border-border bg-muted/40 px-3 py-2 text-label text-muted-foreground"
                        >
                          <ImageIcon className="h-4 w-4 shrink-0" />
                          <span className="truncate">{photo.filename ?? "photo"}</span>
                        </div>
                      ),
                    )}
                  </div>
                )}
              </section>
            </div>
          )}
        </div>

        {inspection && (
          <div className="flex items-center justify-end gap-2 border-t border-border pt-4">
            {approved ? (
              <Badge variant="secondary">Approved</Badge>
            ) : (
              <>
                <Button
                  variant="outline"
                  onClick={() => {
                    onReject();
                    onOpenChange(false);
                  }}
                >
                  Reject
                </Button>
                <Button onClick={onApprove}>
                  <Send className="mr-1.5 h-3.5 w-3.5" />
                  Approve &amp; deliver
                </Button>
              </>
            )}
          </div>
        )}
      </SheetContent>
    </Sheet>
  );
}
