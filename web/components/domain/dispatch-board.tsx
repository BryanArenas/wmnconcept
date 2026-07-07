"use client";

import * as React from "react";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { UserCheck, CalendarClock, ClipboardList } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { apiFetch, ApiError } from "@/lib/api";
import { cn } from "@/lib/utils";
import type { Inspection, StaffUser } from "@/lib/types";

const STATUS_LABELS: Record<string, string> = {
  unassigned: "Unassigned",
  assigned: "Assigned",
  scheduled: "Scheduled",
  in_progress: "In progress",
};

const STATUS_VARIANT: Record<
  string,
  "muted" | "secondary" | "default" | "outline"
> = {
  unassigned: "outline",
  assigned: "secondary",
  scheduled: "default",
  in_progress: "default",
};

interface Props {
  initialInspections: Inspection[];
  inspectors: StaffUser[];
}

export function DispatchBoard({ initialInspections, inspectors }: Props) {
  const [inspections, setInspections] =
    React.useState<Inspection[]>(initialInspections);
  const [assigningId, setAssigningId] = React.useState<string | null>(null);

  function updateInspection(updated: Inspection) {
    setInspections((prev) =>
      prev.map((i) => (i.id === updated.id ? updated : i)),
    );
  }

  const workable = inspections.filter((i) =>
    ["unassigned", "assigned", "scheduled", "in_progress"].includes(i.status),
  );

  if (workable.length === 0) {
    return (
      <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed border-border py-16 text-center text-muted-foreground">
        <ClipboardList className="h-8 w-8 opacity-40" />
        <p className="text-body">Nothing to dispatch.</p>
        <p className="text-label">
          Accepted inspections appear here once they are ready to assign.
        </p>
      </div>
    );
  }

  return (
    <>
      <div className="flex flex-col gap-3">
        {workable.map((inspection) => (
          <InspectionCard
            key={inspection.id}
            inspection={inspection}
            onAssign={() => setAssigningId(inspection.id)}
          />
        ))}
      </div>

      <AssignDialog
        open={assigningId !== null}
        onOpenChange={(o) => !o && setAssigningId(null)}
        inspectionId={assigningId ?? ""}
        inspectors={inspectors}
        onAssigned={(updated) => {
          updateInspection(updated);
          setAssigningId(null);
        }}
      />
    </>
  );
}

function InspectionCard({
  inspection,
  onAssign,
}: {
  inspection: Inspection;
  onAssign: () => void;
}) {
  const canAssign = inspection.status === "unassigned";
  const typeLabel = inspection.inspection_type
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());

  return (
    <div className="rounded-lg border border-border bg-card">
      <div className="flex items-start justify-between gap-4 p-5">
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-2">
            <Badge variant={STATUS_VARIANT[inspection.status] ?? "muted"}>
              {STATUS_LABELS[inspection.status] ?? inspection.status}
            </Badge>
            <span className="text-label text-muted-foreground">{typeLabel}</span>
          </div>
          <p className="text-title text-sm font-medium">
            {inspection.property_address}
          </p>
          <p className="text-label text-muted-foreground">
            {inspection.homeowner_name} · {inspection.agency_name}
          </p>
          {inspection.assigned_inspector_name && (
            <p className="text-label text-muted-foreground">
              <UserCheck className="mr-1 inline h-3 w-3" />
              {inspection.assigned_inspector_name}
              {inspection.scheduled_at
                ? ` · ${formatScheduled(inspection.scheduled_at)}`
                : " (not yet scheduled)"}
            </p>
          )}
        </div>

        {canAssign && (
          <Button size="sm" variant="outline" onClick={onAssign}>
            <CalendarClock className="h-3.5 w-3.5" />
            Assign
          </Button>
        )}
      </div>
    </div>
  );
}

const assignSchema = z.object({
  inspector_id: z.string().min(1, "Select an inspector"),
  scheduled_at: z.string().optional(),
});
type AssignForm = z.infer<typeof assignSchema>;

function AssignDialog({
  open,
  onOpenChange,
  inspectionId,
  inspectors,
  onAssigned,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  inspectionId: string;
  inspectors: StaffUser[];
  onAssigned: (inspection: Inspection) => void;
}) {
  const [serverError, setServerError] = React.useState<string | null>(null);

  const {
    control,
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<AssignForm>({ resolver: zodResolver(assignSchema) });

  function handleOpenChange(o: boolean) {
    onOpenChange(o);
    if (!o) {
      reset();
      setServerError(null);
    }
  }

  async function onSubmit(values: AssignForm) {
    setServerError(null);
    try {
      // Step 1: assign inspector (unassigned → assigned)
      const { data: assigned } = await apiFetch<{ data: Inspection }>(
        `/api/v1/inspections/${inspectionId}/assign`,
        {
          method: "POST",
          body: JSON.stringify({ inspection: { inspector_id: values.inspector_id } }),
        },
      );

      // Step 2: schedule if a datetime was provided (assigned → scheduled)
      if (values.scheduled_at) {
        const { data: scheduled } = await apiFetch<{ data: Inspection }>(
          `/api/v1/inspections/${inspectionId}/schedule`,
          {
            method: "POST",
            body: JSON.stringify({
              inspection: { scheduled_at: values.scheduled_at },
            }),
          },
        );
        onAssigned(scheduled);
      } else {
        onAssigned(assigned);
      }

      reset();
    } catch (err) {
      setServerError(
        err instanceof ApiError ? err.message : "An unexpected error occurred.",
      );
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="sm:max-w-[420px]">
        <DialogHeader>
          <DialogTitle>Assign inspector</DialogTitle>
        </DialogHeader>
        <form
          id="assign-form"
          onSubmit={handleSubmit(onSubmit)}
          className="flex flex-col gap-4"
        >
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="inspector">Inspector *</Label>
            <Controller
              name="inspector_id"
              control={control}
              render={({ field }) => (
                <Select onValueChange={field.onChange} value={field.value ?? ""}>
                  <SelectTrigger id="inspector">
                    <SelectValue placeholder="Select inspector" />
                  </SelectTrigger>
                  <SelectContent>
                    {inspectors.map((u) => (
                      <SelectItem key={u.id} value={u.id}>
                        {u.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
            {errors.inspector_id && (
              <p className="text-label text-destructive">
                {errors.inspector_id.message}
              </p>
            )}
          </div>

          <div className="flex flex-col gap-1.5">
            <Label htmlFor="scheduled_at">Scheduled date &amp; time (optional)</Label>
            <input
              id="scheduled_at"
              type="datetime-local"
              className={cn(
                "flex h-9 w-full rounded-md border border-input bg-background px-3 py-2 text-sm",
                "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
              )}
              {...register("scheduled_at")}
            />
            <p className="text-label text-muted-foreground">
              Sets date + fires T-24h reminder automatically.
            </p>
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
          <Button type="submit" form="assign-form" disabled={isSubmitting}>
            {isSubmitting ? "Assigning…" : "Assign"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function formatScheduled(iso: string): string {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(iso));
}
