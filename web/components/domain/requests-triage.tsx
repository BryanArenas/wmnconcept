"use client";

import * as React from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Check, X, ClipboardList } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { apiFetch, ApiError } from "@/lib/api";
import { cn } from "@/lib/utils";
import type { InspectionRequest, InspectionTypeConfig } from "@/lib/types";

interface Props {
  initialRequests: InspectionRequest[];
  configs: InspectionTypeConfig[];
}

type RequestState =
  | { kind: "pending"; req: InspectionRequest }
  | { kind: "accepted"; req: InspectionRequest }
  | { kind: "declined"; req: InspectionRequest };

export function RequestsTriage({ initialRequests, configs }: Props) {
  const [states, setStates] = React.useState<RequestState[]>(
    initialRequests.map((r) => ({ kind: "pending", req: r })),
  );
  const [decliningId, setDecliningId] = React.useState<string | null>(null);

  const pending = states.filter((s) => s.kind === "pending");

  async function handleAccept(id: string) {
    try {
      await apiFetch(`/api/v1/inspection_requests/${id}/accept`, {
        method: "POST",
      });
      setStates((prev) =>
        prev.map((s) =>
          s.req.id === id ? { kind: "accepted", req: s.req } : s,
        ),
      );
    } catch {
      // leave in pending; a banner would be ideal but avoids toast dependency
    }
  }

  function handleDeclined(id: string) {
    setStates((prev) =>
      prev.map((s) =>
        s.req.id === id ? { kind: "declined", req: s.req } : s,
      ),
    );
    setDecliningId(null);
  }

  if (states.length === 0) {
    return (
      <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed border-border py-16 text-center text-muted-foreground">
        <ClipboardList className="h-8 w-8 opacity-40" />
        <p className="text-body">No pending requests.</p>
        <p className="text-label">
          New agency submissions land here. Accept to spawn inspections or
          decline with a reason.
        </p>
      </div>
    );
  }

  return (
    <>
      <div className="flex flex-col gap-3">
        {states.map(({ kind, req }) => (
          <RequestCard
            key={req.id}
            req={req}
            kind={kind}
            configs={configs}
            onAccept={() => handleAccept(req.id)}
            onDecline={() => setDecliningId(req.id)}
          />
        ))}
      </div>

      {pending.length > 0 && (
        <p className="text-label text-muted-foreground">
          {pending.length} pending · {states.length - pending.length} actioned
          this session
        </p>
      )}

      <DeclineDialog
        open={decliningId !== null}
        onOpenChange={(o) => !o && setDecliningId(null)}
        requestId={decliningId ?? ""}
        onDeclined={handleDeclined}
      />
    </>
  );
}

function RequestCard({
  req,
  kind,
  configs,
  onAccept,
  onDecline,
}: {
  req: InspectionRequest;
  kind: "pending" | "accepted" | "declined";
  configs: InspectionTypeConfig[];
  onAccept: () => void;
  onDecline: () => void;
}) {
  const typeTotal = req.requested_types.reduce((sum, t) => {
    const cfg = configs.find((c) => c.inspection_type === t);
    return sum + (cfg?.price_cents ?? 0);
  }, 0);

  return (
    <div
      className={cn(
        "rounded-lg border border-border bg-card",
        kind === "accepted" && "opacity-60",
        kind === "declined" && "opacity-50",
      )}
    >
      <div className="flex flex-col gap-3 p-5">
        {/* Header row */}
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col gap-0.5">
            <p className="text-title text-sm font-medium">{req.agency_name}</p>
            <p className="text-label text-muted-foreground">
              {req.property.address},{" "}
              {[req.property.city, req.property.state, req.property.zip]
                .filter(Boolean)
                .join(" ")}
            </p>
          </div>
          {kind === "accepted" && (
            <Badge variant="default" className="shrink-0 gap-1">
              <Check className="h-3 w-3" />
              Accepted
            </Badge>
          )}
          {kind === "declined" && (
            <Badge variant="secondary" className="shrink-0 gap-1">
              <X className="h-3 w-3" />
              Declined
            </Badge>
          )}
        </div>

        {/* Homeowner */}
        <p className="text-label text-muted-foreground">
          {req.homeowner.name}
          {req.homeowner.email ? ` · ${req.homeowner.email}` : ""}
        </p>

        {/* Type chips + total */}
        <div className="flex flex-wrap items-center gap-2">
          {req.requested_types.map((t) => {
            const cfg = configs.find((c) => c.inspection_type === t);
            return (
              <span
                key={t}
                className="inline-flex items-center gap-1 rounded-full border border-border px-2.5 py-0.5 text-label"
              >
                {cfg?.label ?? t}
                {cfg ? (
                  <span className="text-muted-foreground">
                    · ${(cfg.price_cents / 100).toFixed(2)}
                  </span>
                ) : null}
              </span>
            );
          })}
          {typeTotal > 0 && (
            <span className="ml-auto text-label font-medium">
              Total ${(typeTotal / 100).toFixed(2)}
            </span>
          )}
        </div>

        {req.preferred_dates && (
          <p className="text-label text-muted-foreground">
            Availability: {req.preferred_dates}
          </p>
        )}
      </div>

      {kind === "pending" && (
        <div className="flex gap-2 border-t border-border px-5 py-3">
          <Button size="sm" onClick={onAccept}>
            <Check className="h-3.5 w-3.5" />
            Accept
          </Button>
          <Button size="sm" variant="outline" onClick={onDecline}>
            <X className="h-3.5 w-3.5" />
            Decline
          </Button>
        </div>
      )}
    </div>
  );
}

const declineSchema = z.object({
  reason: z.string().min(1, "A reason is required"),
});
type DeclineForm = z.infer<typeof declineSchema>;

function DeclineDialog({
  open,
  onOpenChange,
  requestId,
  onDeclined,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  requestId: string;
  onDeclined: (id: string) => void;
}) {
  const [serverError, setServerError] = React.useState<string | null>(null);

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<DeclineForm>({ resolver: zodResolver(declineSchema) });

  function handleOpenChange(o: boolean) {
    onOpenChange(o);
    if (!o) {
      reset();
      setServerError(null);
    }
  }

  async function onSubmit(values: DeclineForm) {
    setServerError(null);
    try {
      await apiFetch(`/api/v1/inspection_requests/${requestId}/decline`, {
        method: "POST",
        body: JSON.stringify({
          inspection_request: { decline_reason: values.reason },
        }),
      });
      reset();
      onDeclined(requestId);
    } catch (err) {
      setServerError(
        err instanceof ApiError ? err.message : "An error occurred.",
      );
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="sm:max-w-[420px]">
        <DialogHeader>
          <DialogTitle>Decline request</DialogTitle>
        </DialogHeader>
        <form
          id="decline-form"
          onSubmit={handleSubmit(onSubmit)}
          className="flex flex-col gap-3"
        >
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="decline-reason">Reason *</Label>
            <Textarea
              id="decline-reason"
              placeholder="Outside service area, unavailable dates, etc."
              rows={3}
              {...register("reason")}
            />
            {errors.reason && (
              <p className="text-label text-destructive">
                {errors.reason.message}
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
            form="decline-form"
            variant="destructive"
            disabled={isSubmitting}
          >
            {isSubmitting ? "Declining…" : "Decline request"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
