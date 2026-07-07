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

// A lightweight staff member record (for dispatch inspector dropdown, etc.)
export interface StaffUser {
  id: string;
  name: string;
  email: string;
  role: Role;
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

// M5 — field capture

export type FormFieldType = "text" | "number" | "boolean" | "select" | "multi_select";

export interface FormField {
  key: string;
  label: string;
  type: FormFieldType;
  required: boolean;
  options?: string[];
}

export interface FormSchema {
  fields: FormField[];
}

export interface InspectionFormTemplate {
  id: number;
  inspection_type: string;
  schema: FormSchema;
  active: boolean;
  position: number;
}

export interface InspectionPhoto {
  id: string;
  inspection_id: string;
  s3_key: string;
  upload_state: "pending" | "uploaded";
  filename: string | null;
  content_type: string | null;
  created_at: string;
}

export interface InspectionFormResponse {
  id: number;
  inspection_id: string;
  responses: Record<string, string | number | boolean | string[]>;
  updated_at: string;
}

// M4 — dispatch + calendar (mirrors InspectionSerializer)
export interface Inspection {
  id: string;
  status: InspectionStatus;
  inspection_type: string;
  price_cents: number;
  agency_id: string;
  agency_name: string;
  property_id: string;
  property_address: string;
  homeowner_id: string;
  homeowner_name: string;
  inspection_request_id: string;
  assigned_inspector_id: string | null;
  assigned_inspector_name: string | null;
  scheduled_at: string | null;
  started_at: string | null;
  submitted_at: string | null;
  approved_at: string | null;
  delivered_at: string | null;
  rejection_note: string | null;
  // M6 — report/invoice presence (mirrors InspectionSerializer)
  has_report: boolean;
  report_generated_at: string | null;
  report_delivered_at: string | null;
  has_invoice: boolean;
  invoice_amount_cents: number | null;
  invoice_status: InvoiceStatus | null;
  created_at: string;
}

// M6 — report + delivery ledger (mirrors ReportSerializer)
export interface ReportDelivery {
  email: string;
  role: string;
  status: string;
  delivered_at: string;
}

export interface Report {
  id: string;
  inspection_id: string;
  filename: string;
  generated_at: string;
  delivered_at: string | null;
  delivered_to: ReportDelivery[];
  download_url: string | null;
}

// M6/M7 — billing (mirrors InvoiceSerializer)
export type InvoiceStatus = "draft" | "sent" | "paid" | "void";
export type InvoiceBillingMode = "fixed_rate" | "commission";

export interface Invoice {
  id: string;
  inspection_id: string;
  agency_id: string;
  amount_cents: number;
  billing_mode: InvoiceBillingMode;
  status: InvoiceStatus;
  stripe_invoice_id: string | null;
  due_at: string | null;
  created_at: string;
}
