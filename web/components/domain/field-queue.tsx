"use client";

import * as React from "react";
import { ClipboardCheck } from "lucide-react";
import { FieldInspectionCard } from "@/components/domain/field-inspection-card";
import type { Inspection } from "@/lib/types";

interface Props {
  initialInspections: Inspection[];
}

export function FieldQueue({ initialInspections }: Props) {
  const [inspections, setInspections] =
    React.useState<Inspection[]>(initialInspections);

  function updateInspection(updated: Inspection) {
    setInspections((prev) =>
      prev.map((i) => (i.id === updated.id ? updated : i)),
    );
  }

  const active = inspections.filter((i) =>
    ["scheduled", "in_progress"].includes(i.status),
  );

  if (active.length === 0) {
    return (
      <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed border-border py-16 text-center text-muted-foreground">
        <ClipboardCheck className="h-8 w-8 opacity-40" />
        <p className="text-body">No active inspections.</p>
        <p className="text-label">
          Assignments scheduled for today appear here once the coordinator dispatches them.
        </p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      {active.map((inspection) => (
        <FieldInspectionCard
          key={inspection.id}
          inspection={inspection}
          onUpdated={updateInspection}
        />
      ))}
    </div>
  );
}
