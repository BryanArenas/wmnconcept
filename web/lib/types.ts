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
