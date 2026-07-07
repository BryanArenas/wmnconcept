"use client";

import * as React from "react";
import { ChevronDown, ChevronUp, Play, Send } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { DynamicFormRenderer } from "@/components/domain/dynamic-form-renderer";
import { PhotoUpload } from "@/components/domain/photo-upload";
import { apiFetch, ApiError } from "@/lib/api";
import type {
  Inspection,
  InspectionFormTemplate,
  InspectionPhoto,
  InspectionFormResponse,
} from "@/lib/types";

interface Props {
  inspection: Inspection;
  onUpdated: (inspection: Inspection) => void;
}

export function FieldInspectionCard({ inspection: initial, onUpdated }: Props) {
  const [inspection, setInspection] = React.useState(initial);
  const [expanded, setExpanded] = React.useState(false);
  const [template, setTemplate] =
    React.useState<InspectionFormTemplate | null>(null);
  const [photos, setPhotos] = React.useState<InspectionPhoto[]>([]);
  const [formResponse, setFormResponse] =
    React.useState<InspectionFormResponse | null>(null);
  const [serverError, setServerError] = React.useState<string | null>(null);
  const [starting, setStarting] = React.useState(false);
  const [submitting, setSubmitting] = React.useState(false);

  // Load template + existing evidence when card is expanded.
  React.useEffect(() => {
    if (!expanded || inspection.status !== "in_progress") return;

    async function load() {
      try {
        const [tmplRes, photosRes] = await Promise.allSettled([
          apiFetch<{ data: InspectionFormTemplate }>(
            `/api/v1/inspections/${inspection.id}/form_template`,
          ),
          apiFetch<{ data: InspectionPhoto[] }>(
            `/api/v1/inspections/${inspection.id}/photos`,
          ),
        ]);

        if (tmplRes.status === "fulfilled") {
          setTemplate(tmplRes.value.data);
        }
        if (photosRes.status === "fulfilled") {
          setPhotos(photosRes.value.data);
        }
      } catch {
        // non-blocking — template may not be configured yet
      }
    }

    load();
  }, [expanded, inspection.status, inspection.id]);

  async function handleStart() {
    setServerError(null);
    setStarting(true);
    try {
      const res = await apiFetch<{ data: Inspection }>(
        `/api/v1/inspections/${inspection.id}/start`,
        { method: "POST" },
      );
      setInspection(res.data);
      onUpdated(res.data);
      setExpanded(true);
    } catch (err) {
      setServerError(
        err instanceof ApiError ? err.message : "Could not start inspection.",
      );
    } finally {
      setStarting(false);
    }
  }

  async function handleSaveForm(responses: Record<string, unknown>) {
    const res = await apiFetch<{ data: InspectionFormResponse }>(
      `/api/v1/inspections/${inspection.id}/form_response`,
      {
        method: "PUT",
        body: JSON.stringify({ form_response: { responses } }),
      },
    );
    setFormResponse(res.data);
  }

  async function handleSubmit() {
    setServerError(null);
    setSubmitting(true);
    try {
      const res = await apiFetch<{ data: Inspection }>(
        `/api/v1/inspections/${inspection.id}/submit`,
        { method: "POST" },
      );
      setInspection(res.data);
      onUpdated(res.data);
      setExpanded(false);
    } catch (err) {
      setServerError(
        err instanceof ApiError ? err.message : "Submit failed.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  const typeLabel = inspection.inspection_type
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());

  const isInProgress = inspection.status === "in_progress";
  const isSubmitted = inspection.status === "submitted_for_review";
  const isDone = ["approved", "delivered", "cancelled"].includes(inspection.status);

  const uploadedCount = photos.filter((p) => p.upload_state === "uploaded").length;

  return (
    <div className="rounded-lg border border-border bg-card">
      {/* Header row */}
      <div className="flex items-start justify-between gap-4 p-5">
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-2 flex-wrap">
            <Badge
              variant={
                isInProgress ? "default" :
                isSubmitted ? "secondary" :
                isDone ? "muted" : "outline"
              }
            >
              {isInProgress ? "In progress" :
               isSubmitted ? "Submitted" :
               isDone ? inspection.status.replace(/_/g, " ") : "Scheduled"}
            </Badge>
            <span className="text-label text-muted-foreground">{typeLabel}</span>
          </div>
          <p className="text-sm font-medium">{inspection.property_address}</p>
          <p className="text-label text-muted-foreground">{inspection.homeowner_name}</p>
          {inspection.scheduled_at && (
            <p className="text-label text-muted-foreground">
              {new Intl.DateTimeFormat("en-US", {
                month: "short", day: "numeric",
                hour: "numeric", minute: "2-digit",
              }).format(new Date(inspection.scheduled_at))}
            </p>
          )}
        </div>

        <div className="flex shrink-0 gap-2">
          {inspection.status === "scheduled" && (
            <Button size="sm" variant="outline" onClick={handleStart} disabled={starting}>
              <Play className="mr-1.5 h-3.5 w-3.5" />
              {starting ? "Starting…" : "Start"}
            </Button>
          )}
          {isInProgress && (
            <Button
              size="icon"
              variant="ghost"
              onClick={() => setExpanded((v) => !v)}
              aria-expanded={expanded}
              aria-label={expanded ? "Collapse inspection" : "Expand inspection"}
            >
              {expanded ? (
                <ChevronUp className="h-4 w-4" />
              ) : (
                <ChevronDown className="h-4 w-4" />
              )}
            </Button>
          )}
        </div>
      </div>

      {serverError && (
        <p className="px-5 pb-3 text-sm text-destructive">{serverError}</p>
      )}

      {/* Expanded capture panel (in_progress only) */}
      {expanded && isInProgress && (
        <div className="border-t border-border px-5 pb-5 pt-4 flex flex-col gap-6">
          {/* Photos section */}
          <div className="flex flex-col gap-3">
            <p className="text-sm font-semibold">
              Photos
              {uploadedCount > 0 && (
                <span className="ml-2 text-xs font-normal text-muted-foreground">
                  {uploadedCount} uploaded
                </span>
              )}
            </p>
            <PhotoUpload
              inspectionId={inspection.id}
              photos={photos}
              onUploaded={(photo) => setPhotos((prev) => [...prev.filter((p) => p.id !== photo.id), photo])}
            />
          </div>

          {/* Form section */}
          {template && (
            <div className="flex flex-col gap-3">
              <p className="text-sm font-semibold">Form</p>
              <DynamicFormRenderer
                schema={template.schema}
                defaultValues={formResponse?.responses as Record<string, unknown> ?? {}}
                onSave={handleSaveForm}
              />
            </div>
          )}

          {/* Submit */}
          <div className="flex flex-col gap-2 pt-2">
            <Button
              onClick={handleSubmit}
              disabled={submitting || uploadedCount === 0}
              className="w-full sm:w-auto"
            >
              <Send className="mr-2 h-4 w-4" />
              {submitting ? "Submitting…" : "Submit for review"}
            </Button>
            {uploadedCount === 0 && (
              <p className="text-label text-muted-foreground">
                At least one photo is required before submitting.
              </p>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
