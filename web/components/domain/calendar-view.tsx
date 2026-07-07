"use client";

import * as React from "react";
import { CalendarDays } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import type { Inspection } from "@/lib/types";

interface Props {
  inspections: Inspection[];
}

export function CalendarView({ inspections }: Props) {
  // Group by calendar day of scheduled_at (local time).
  const byDay = React.useMemo(() => {
    const map = new Map<string, Inspection[]>();
    for (const insp of inspections) {
      if (!insp.scheduled_at) continue;
      const day = dayKey(insp.scheduled_at);
      const bucket = map.get(day) ?? [];
      bucket.push(insp);
      map.set(day, bucket);
    }
    // Sort days chronologically.
    return [...map.entries()].sort(([a], [b]) => a.localeCompare(b));
  }, [inspections]);

  if (byDay.length === 0) {
    return (
      <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed border-border py-16 text-center text-muted-foreground">
        <CalendarDays className="h-8 w-8 opacity-40" />
        <p className="text-body">No scheduled inspections.</p>
        <p className="text-label">
          Once an inspection is assigned and scheduled it appears here.
        </p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      {byDay.map(([day, dayInspections]) => (
        <section key={day}>
          <p className="mb-3 text-sm font-semibold text-muted-foreground">
            {formatDay(day)}
          </p>
          <div className="flex flex-col gap-2">
            {dayInspections
              .sort((a, b) =>
                (a.scheduled_at ?? "").localeCompare(b.scheduled_at ?? ""),
              )
              .map((insp) => (
                <CalendarCard key={insp.id} inspection={insp} />
              ))}
          </div>
        </section>
      ))}
    </div>
  );
}

function CalendarCard({ inspection }: { inspection: Inspection }) {
  const timeStr = inspection.scheduled_at
    ? new Intl.DateTimeFormat("en-US", {
        hour: "numeric",
        minute: "2-digit",
      }).format(new Date(inspection.scheduled_at))
    : null;

  const typeLabel = inspection.inspection_type
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());

  return (
    <div className="flex items-start gap-4 rounded-lg border border-border bg-card px-5 py-4">
      {/* Time column */}
      <div className="w-16 shrink-0 text-right">
        <p className="text-sm font-medium tabular-nums">{timeStr}</p>
      </div>

      {/* Divider */}
      <div className="mt-1 h-4 w-px shrink-0 bg-border" />

      {/* Content */}
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <div className="flex items-center gap-2">
          <p className="truncate text-sm font-medium">
            {inspection.property_address}
          </p>
          <Badge variant="muted" className="shrink-0">
            {typeLabel}
          </Badge>
        </div>
        <p className="text-label text-muted-foreground">
          {inspection.homeowner_name}
          {inspection.assigned_inspector_name
            ? ` · ${inspection.assigned_inspector_name}`
            : ""}
        </p>
      </div>
    </div>
  );
}

// "2024-03-15" key from an ISO string, based on local time.
function dayKey(iso: string): string {
  const d = new Date(iso);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function formatDay(key: string): string {
  // key is "YYYY-MM-DD"; parse as noon local time to avoid timezone edge cases.
  const d = new Date(`${key}T12:00:00`);
  return new Intl.DateTimeFormat("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric",
  }).format(d);
}
