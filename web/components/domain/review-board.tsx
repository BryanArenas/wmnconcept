"use client";

import * as React from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { CheckCircle2, ClipboardCheck, Send } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { StatusDot } from "@/components/domain/status-dot";
import { ReportCard } from "@/components/domain/report-card";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { apiFetch, ApiError } from "@/lib/api";
import type { Inspection } from "@/lib/types";

interface Props {
  initialQueue: Inspection[];
  recentlyDelivered: Inspection[];
}

// Manager review queue (§8.13). Approve fires the report pipeline; the
// inspection leaves the queue and reappears under "Recently delivered" once the
// worker completes generation + delivery.
export function ReviewBoard({ initialQueue, recentlyDelivered }: Props) {
  const [queue, setQueue] = React.useState<Inspection[]>(initialQueue);
  const [rejectingId, setRejectingId] = React.useState<string | null>(null);
  const [approvedIds, setApprovedIds] = React.useState<Set<string>>(new Set());

  function removeFromQueue(id: string) {
    setQueue((prev) => prev.filter((i) => i.id !== id));
  }

  async function handleApprove(inspection: Inspection) {
    try {
      await apiFetch(`/api/v1/inspections/${inspection.id}/approve`, {
        method: "POST",
      });
      setApprovedIds((prev) => new Set(prev).add(inspection.id));
      // Brief confirmation, then drop from the active queue.
      setTimeout(() => removeFromQueue(inspection.id), 1200);
    } catch {
      // Surface via the card's own error would be ideal; keep it in queue.
    }
  }

  return (
    <div className="flex flex-col gap-8">
      <section className="flex flex-col gap-3">
        {queue.length === 0 ? (
          <EmptyQueue />
        ) : (
          queue.map((inspection) => (
            <ReviewCard
              key={inspection.id}
              inspection={inspection}
              approved={approvedIds.has(inspection.id)}
              onApprove={() => handleApprove(inspection)}
              onReject={() => setRejectingId(inspection.id)}
            />
          ))
        )}
      </section>

      {recentlyDelivered.length > 0 && (
        <section className="flex flex-col gap-3">
          <p className="text-sm font-semibold text-muted-foreground">
            Recently delivered
          </p>
          {recentlyDelivered.map((inspection) => (
            <DeliveredRow key={inspection.id} inspection={inspection} />
          ))}
        </section>
      )}

      <RejectDialog
        open={rejectingId !== null}
        onOpenChange={(o) => !o && setRejectingId(null)}
        inspectionId={rejectingId ?? ""}
        onRejected={(id) => {
          removeFromQueue(id);
          setRejectingId(null);
        }}
      />
    </div>
  );
}

function ReviewCard({
  inspection,
  approved,
  onApprove,
  onReject,
}: {
  inspection: Inspection;
  approved: boolean;
  onApprove: () => void;
  onReject: () => void;
}) {
  const typeLabel = inspection.inspection_type
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());

  return (
    <div className="rounded-lg border border-border bg-card">
      <div className="flex items-start justify-between gap-4 p-5">
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-2">
            <StatusDot status={inspection.status} />
            <span className="text-label text-muted-foreground">{typeLabel}</span>
          </div>
          <p className="text-sm font-medium">{inspection.property_address}</p>
          <p className="text-label text-muted-foreground">
            {inspection.homeowner_name} · {inspection.agency_name}
          </p>
          {inspection.assigned_inspector_name && (
            <p className="text-label text-muted-foreground">
              Inspector: {inspection.assigned_inspector_name}
            </p>
          )}
        </div>

        {approved ? (
          <Badge variant="secondary" className="shrink-0">
            <CheckCircle2 className="mr-1 h-3.5 w-3.5 text-emerald-600" />
            Approved
          </Badge>
        ) : (
          <div className="flex shrink-0 gap-2">
            <Button size="sm" variant="outline" onClick={onReject}>
              Reject
            </Button>
            <Button size="sm" onClick={onApprove}>
              <Send className="mr-1.5 h-3.5 w-3.5" />
              Approve &amp; deliver
            </Button>
          </div>
        )}
      </div>
      {!approved && (
        <p className="border-t border-border px-5 py-3 text-label text-muted-foreground">
          Approving generates the PDF, delivers it to the homeowner and agency, and
          creates the invoice.
        </p>
      )}
    </div>
  );
}

function DeliveredRow({ inspection }: { inspection: Inspection }) {
  const typeLabel = inspection.inspection_type
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());

  return (
    <div className="flex flex-col gap-3 rounded-lg border border-border bg-card p-5">
      <div className="flex items-center justify-between gap-4">
        <div className="flex flex-col gap-0.5">
          <div className="flex items-center gap-2">
            <StatusDot status={inspection.status} />
            <span className="text-label text-muted-foreground">{typeLabel}</span>
          </div>
          <p className="text-sm font-medium">{inspection.property_address}</p>
          <p className="text-label text-muted-foreground">
            {inspection.homeowner_name} · {inspection.agency_name}
          </p>
        </div>
      </div>
      {inspection.has_report && (
        <ReportCard
          inspectionId={inspection.id}
          deliveredAt={inspection.report_delivered_at}
        />
      )}
    </div>
  );
}

const rejectSchema = z.object({
  rejection_note: z.string().min(1, "A note is required to send it back"),
});
type RejectForm = z.infer<typeof rejectSchema>;

function RejectDialog({
  open,
  onOpenChange,
  inspectionId,
  onRejected,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  inspectionId: string;
  onRejected: (id: string) => void;
}) {
  const [serverError, setServerError] = React.useState<string | null>(null);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<RejectForm>({ resolver: zodResolver(rejectSchema) });

  function handleOpenChange(o: boolean) {
    onOpenChange(o);
    if (!o) {
      reset();
      setServerError(null);
    }
  }

  async function onSubmit(values: RejectForm) {
    setServerError(null);
    try {
      await apiFetch(`/api/v1/inspections/${inspectionId}/reject`, {
        method: "POST",
        body: JSON.stringify({ inspection: values }),
      });
      reset();
      onRejected(inspectionId);
    } catch (err) {
      setServerError(
        err instanceof ApiError ? err.message : "An unexpected error occurred.",
      );
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="sm:max-w-[440px]">
        <DialogHeader>
          <DialogTitle>Send back to inspector</DialogTitle>
        </DialogHeader>
        <form
          id="reject-form"
          onSubmit={handleSubmit(onSubmit)}
          className="flex flex-col gap-3"
        >
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="rejection_note">Reason *</Label>
            <Textarea
              id="rejection_note"
              rows={4}
              placeholder="What needs to be corrected?"
              {...register("rejection_note")}
            />
            {errors.rejection_note && (
              <p className="text-label text-destructive">
                {errors.rejection_note.message}
              </p>
            )}
          </div>
          {serverError && (
            <p className="text-label text-destructive">{serverError}</p>
          )}
        </form>
        <DialogFooter>
          <Button
            type="button"
            variant="outline"
            onClick={() => handleOpenChange(false)}
            disabled={isSubmitting}
          >
            Cancel
          </Button>
          <Button
            type="submit"
            form="reject-form"
            variant="destructive"
            disabled={isSubmitting}
          >
            {isSubmitting ? "Sending…" : "Send back"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function EmptyQueue() {
  return (
    <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed border-border py-16 text-center text-muted-foreground">
      <ClipboardCheck className="h-8 w-8 opacity-40" />
      <p className="text-body">Nothing awaiting review.</p>
      <p className="text-label">
        Submitted inspections land here for the quality gate.
      </p>
    </div>
  );
}
