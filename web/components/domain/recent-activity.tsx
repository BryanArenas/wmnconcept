import {
  ClipboardPlus,
  UserCheck,
  CalendarClock,
  Play,
  Send,
  CheckCircle2,
  RotateCcw,
  Truck,
  CreditCard,
  XCircle,
  Activity as ActivityIcon,
  type LucideIcon,
} from "lucide-react";
import type { ActivityEvent } from "@/lib/types";

// Maps an inspection-timeline event kind to an icon + accent. Kinds come from
// Inspection#record_event (spec §6 side effects) plus payment_received.
const KIND_META: Record<string, { icon: LucideIcon; tone: string }> = {
  created: { icon: ClipboardPlus, tone: "text-sky-600" },
  assigned: { icon: UserCheck, tone: "text-indigo-600" },
  scheduled: { icon: CalendarClock, tone: "text-violet-600" },
  started: { icon: Play, tone: "text-amber-600" },
  submitted: { icon: Send, tone: "text-blue-600" },
  approved: { icon: CheckCircle2, tone: "text-emerald-600" },
  rejected: { icon: RotateCcw, tone: "text-orange-600" },
  delivered: { icon: Truck, tone: "text-emerald-700" },
  payment_received: { icon: CreditCard, tone: "text-emerald-600" },
  cancelled: { icon: XCircle, tone: "text-destructive" },
};

function relativeTime(iso: string): string {
  const then = new Date(iso).getTime();
  const diffMs = Date.now() - then;
  const mins = Math.round(diffMs / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.round(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.round(hrs / 24);
  if (days < 7) return `${days}d ago`;
  return new Date(iso).toLocaleDateString();
}

export function RecentActivity({ events }: { events: ActivityEvent[] }) {
  if (events.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-border py-12 text-center">
        <ActivityIcon className="mx-auto h-7 w-7 text-muted-foreground/40" />
        <p className="mt-3 text-body font-medium text-foreground">No activity yet</p>
        <p className="mt-1 text-body text-muted-foreground">
          New requests, schedules, and payments will show up here.
        </p>
      </div>
    );
  }

  return (
    <ol className="overflow-hidden rounded-lg border border-border">
      {events.map((e, i) => {
        const meta = KIND_META[e.kind] ?? { icon: ActivityIcon, tone: "text-muted-foreground" };
        const Icon = meta.icon;
        return (
          <li
            key={e.id}
            className={
              i < events.length - 1
                ? "flex items-start gap-3 border-b border-border px-4 py-3"
                : "flex items-start gap-3 px-4 py-3"
            }
          >
            <Icon className={`mt-0.5 h-4 w-4 shrink-0 ${meta.tone}`} strokeWidth={2} />
            <div className="min-w-0 flex-1">
              <p className="text-body text-foreground">{e.message}</p>
              <p className="mt-0.5 text-label text-muted-foreground">
                {e.property_address ? `${e.property_address} · ` : ""}
                {e.actor_label ? `${e.actor_label} · ` : ""}
                {relativeTime(e.occurred_at)}
              </p>
            </div>
          </li>
        );
      })}
    </ol>
  );
}
