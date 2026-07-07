import type { InspectionStatus } from "./types";

// Client mirror of the §6 status machine: label + dot color per state.
// Status color is a separate design token from the brand accent (§5.1) — a dot
// encodes real state and legitimately earns its own hue. Dots are the ONLY
// place these colors appear; rows stay hairline-bordered, never filled.
export interface StatusMeta {
  label: string;
  /** Dot hex from the §5.1 status palette. */
  color: string;
}

export const INSPECTION_STATUS: Record<InspectionStatus, StatusMeta> = {
  unassigned: { label: "Unassigned", color: "#A8A29E" }, // stone-400
  assigned: { label: "Assigned", color: "#78716C" }, // stone-500
  scheduled: { label: "Scheduled", color: "#2563EB" }, // blue-600
  in_progress: { label: "In progress", color: "#0891B2" }, // cyan-600
  submitted_for_review: { label: "Awaiting review", color: "#D97706" }, // amber-600
  approved: { label: "Approved", color: "#059669" }, // emerald-600
  delivered: { label: "Delivered", color: "#059669" }, // emerald-600
  rejected: { label: "Rejected", color: "#B91C1C" }, // red-700
  cancelled: { label: "Cancelled", color: "#B91C1C" }, // red-700
};

// Allowed transitions (client mirror of §6). Authoritative enforcement lives in
// the Rails AASM machine; this only gates which actions the UI offers so we
// never present a control the server would reject.
export const ALLOWED_TRANSITIONS: Record<InspectionStatus, InspectionStatus[]> = {
  unassigned: ["assigned", "cancelled"],
  assigned: ["scheduled", "cancelled"],
  scheduled: ["in_progress", "cancelled"],
  in_progress: ["submitted_for_review", "cancelled"],
  submitted_for_review: ["approved", "in_progress"], // approve | reject(→rework)
  approved: ["delivered"], // pipeline-driven; never a manual control
  delivered: [],
  rejected: [],
  cancelled: [],
};

export function canTransition(
  from: InspectionStatus,
  to: InspectionStatus,
): boolean {
  return ALLOWED_TRANSITIONS[from]?.includes(to) ?? false;
}
