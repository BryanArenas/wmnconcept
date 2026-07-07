// Shared domain types mirroring the Rails API serializers (app/serializers/*).
// Keep these in sync with the JSON shapes the API returns.

export type Role = "org_admin" | "coordinator" | "inspector" | "manager";

// Which app shell a signed-in identity belongs to. Agency users (M2) live in a
// separate table and resolve to the agency surface.
export type Surface = "staff" | "field" | "agency";

export interface Organization {
  id: string;
  name: string;
  subdomain: string;
  brand_primary_hex: string;
  logo_url: string | null;
  timezone: string;
}

export interface Office {
  id: number;
  name: string;
  city: string | null;
}

export interface User {
  id: string;
  name: string;
  email: string;
  role: Role;
  license_number: string | null;
  active: boolean;
  office: Office | null;
  organization: Organization | null;
}

// The nine-state inspection machine (spec §6). Status is stored server-side,
// never derived; this union is the client mirror of that contract.
export type InspectionStatus =
  | "unassigned"
  | "assigned"
  | "scheduled"
  | "in_progress"
  | "submitted_for_review"
  | "approved"
  | "delivered"
  | "rejected"
  | "cancelled";

// Standard index-action envelope (cursor pagination, spec §4).
export interface Paginated<T> {
  data: T[];
  meta: { next_cursor: string | null };
}

export type AgencyType = "insurance" | "real_estate" | "other";
export type BillingMode = "fixed_rate" | "commission";

export interface Agency {
  id: string;
  name: string;
  type: AgencyType;
  billing_mode: BillingMode;
  commission_rate: string | null;
  primary_contact_email: string | null;
  phone: string | null;
  active: boolean;
}

// M3 — inspection intake + triage

export interface InspectionTypeConfig {
  id: number;
  inspection_type: string;
  label: string;
  price_cents: number;
  active: boolean;
}

export interface PropertySnippet {
  id: string;
  address: string;
  city: string;
  state: string;
  zip: string | null;
}

export interface HomeownerSnippet {
  id: string;
  name: string;
  email: string | null;
  phone: string | null;
}

export type InspectionRequestStatus = "submitted" | "accepted" | "declined";

export interface InspectionRequest {
  id: string;
  status: InspectionRequestStatus;
  requested_types: string[];
  preferred_dates: string | null;
  notes: string | null;
  decline_reason: string | null;
  agency_id: string;
  agency_name: string;
  property: PropertySnippet;
  homeowner: HomeownerSnippet;
  created_at: string;
}
