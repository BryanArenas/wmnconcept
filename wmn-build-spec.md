# Wind Mitigation Network — Product & Design Specification

**Build handoff for Claude Code · MVP**
Stack: Next.js (App Router, TS) + Rails 8 (API) + PostgreSQL · shadcn/ui (new-york) + Tailwind
This document is self-contained. It supersedes the earlier product spec and folds the design system (derived from the approved prototype) into a single executable brief.

---

## 0. How to use this document

Build in the order given in §12 (Build Sequence). Each numbered milestone is a shippable slice with its own tests. Do not build anything under "Out of scope" (§13). Where a value is a placeholder (form schema, non-wind-mitigation prices), it is labelled `PLACEHOLDER` — wire it as data/config so it can be swapped without code changes; never hard-code it into logic. Two decisions are unresolved (§13, white-label and "Oracle"); build the MVP so neither is foreclosed, and do not build machinery for either.

Non-negotiables carried from the technical defaults: UUID PKs on externally-exposed resources, bigint on internal join tables; `organization_id` on every tenant-scoped table; cursor pagination on lists; error envelope `{ error: { code, message, details } }`; Solid Queue for jobs; Stripe with idempotent webhooks; RSpec request specs (happy + auth-fail + one edge) on every action; FactoryBot, no fixtures; reversible migrations with indexes in the same migration.

---

## 1. Product Summary

A multi-tenant-ready (single tenant at launch) platform that runs the full third-party insurance-inspection loop for Wind Mitigation Network LLC. A referring agency requests an inspection through a self-service dashboard; the office assigns and schedules it; a licensed inspector performs it in the field capturing photos and standardized form data; a manager reviews and approves; the finished PDF report is delivered to every associated party within the company's 24-hour promise; invoicing and payment follow automatically. The wedge is the agency portal — "enter your client's info and we handle the rest" — which is the company's existing sales pitch and its growth engine.

**Primary audiences and their jobs**
- Agency partner (insurance / real-estate agent): request inspections and retrieve reports with zero phone/email friction.
- Office coordinator: triage requests, assign inspectors, schedule.
- Inspector: perform inspections in the field, capture data once, digitally.
- Inspection manager: quality-gate reports before they reach clients.
- Org admin: onboard agencies, oversee billing.
- Homeowner (no login): receives the finished report by email.

---

## 2. Roles & Access

| Role | Table | Surface | Can |
|---|---|---|---|
| Agency user | `agency_users` | Agency portal | Submit requests; view own inspections/reports/invoices |
| Coordinator | `users` | Staff portal | Triage requests; assign; schedule; view all |
| Inspector | `users` | Field surface | View own queue; perform + submit inspections |
| Manager | `users` | Staff portal | Review; approve (fires delivery+invoice); reject |
| Org admin | `users` | Staff portal | All coordinator/manager rights + onboard agencies, manage billing |

Authorization via Pundit policies; every list endpoint is scoped (agency → own agency; inspector → own assignments; staff → org-wide). Staff and agency identities live in separate tables by design so partner auth and staff auth never share a surface.

---

## 3. Data Model (reference)

All tenant-scoped tables carry `organization_id` (bigint FK, indexed, not null), enforced through a query object / Pundit scope — not a bare `default_scope`. UUID PKs on anything reachable by URL/API; bigint on internal joins.

| Table | PK | Key columns | Notes |
|---|---|---|---|
| `organizations` | uuid | name, subdomain (uniq), primary_email, phone, timezone, logo_url, brand_primary_hex | Tenant root. One row at launch. |
| `offices` | bigint | organization_id, name, address, city, state, zip, phone | FT Myers HQ + Cape Coral. |
| `users` | uuid | organization_id, email (citext, uniq/org), name, role enum(org_admin,coordinator,inspector,manager), license_number, office_id, active, omniauth(provider,uid) | Staff + inspectors. |
| `agencies` | uuid | organization_id, name, type enum(insurance,real_estate,other), primary_contact_email, phone, commission_rate, billing_mode enum(fixed_rate,commission), active | Referral partners. |
| `agency_users` | uuid | organization_id, agency_id, email (citext), name, omniauth, active | Partner logins. |
| `properties` | uuid | organization_id, address, city, state(FL), zip, county, lat, lng, year_built, structure_type enum(single_family,condo,hoa_master,commercial,mobile) | Deduped per org by normalized address. |
| `homeowners` | uuid | organization_id, name, email, phone | End client; no login at MVP. |
| `inspection_requests` | uuid | organization_id, agency_id, submitted_by_agency_user_id, property_id, homeowner_id, requested_types[], preferred_dates, notes, status enum(submitted,accepted,declined) | Agency intake. |
| `inspections` | uuid | organization_id, inspection_request_id, agency_id, property_id, homeowner_id, inspection_type enum(7), assigned_inspector_id, scheduled_at, status enum(9), price_cents, office_id | **The unit of work & billing. Status = state machine (§6).** |
| `inspection_form_templates` | bigint | organization_id (null=global), inspection_type, version, schema jsonb, active | Versioned hard-coded schemas. Not a form builder. |
| `inspection_form_responses` | uuid | organization_id, inspection_id (uniq), template_id, answers jsonb, geotag_lat/lng, completed_at | Field capture. |
| `inspection_photos` | uuid | organization_id, inspection_id, s3_key, caption, field_ref, lat/lng, taken_at, position | Object storage, not DB. |
| `reports` | uuid | organization_id, inspection_id (uniq), s3_key, generated_at, delivered_at, delivered_to jsonb | Generated PDF + delivery ledger. |
| `invoices` | uuid | organization_id, agency_id, inspection_id, amount_cents, billing_mode, status enum(draft,sent,paid,void), stripe_invoice_id, due_at | |
| `payments` | uuid | organization_id, invoice_id, amount_cents, method enum(card,cash,ach), stripe_payment_intent_id, paid_at | |
| `webhook_events` | bigint | provider, external_id (uniq w/ provider), payload jsonb, processed_at | Stripe idempotency ledger. |

Indexes at minimum: every FK; `inspections[organization_id,status]`, `[assigned_inspector_id,scheduled_at]`; `inspection_requests[organization_id,status]`; `invoices[organization_id,status]`; unique `inspection_form_templates[inspection_type,version]`; unique `webhook_events[provider,external_id]`.

---

## 4. API Surface (reference)

REST + JSON under `/api/v1/`. Auth column: `agency`=agency_user session, `staff`=internal, `role:x`=Pundit-gated. Cursor pagination on all index actions. Error envelope on every non-2xx.

| Method | Path | Action | Auth |
|---|---|---|---|
| POST | /auth/:provider/callback | sessions#create | public |
| DELETE | /session | sessions#destroy | any |
| GET | /me | me#show | any |
| POST | /inspection_requests | inspection_requests#create | agency |
| GET | /inspection_requests | #index | agency, staff |
| GET | /inspection_requests/:id | #show | agency(own), staff |
| POST | /inspection_requests/:id/accept | #accept | role:coordinator |
| POST | /inspection_requests/:id/decline | #decline | role:coordinator |
| GET | /inspections | #index (filter: scope, status) | staff, inspector(own), agency(own) |
| GET | /inspections/:id | #show | scoped |
| PATCH | /inspections/:id/assign | #assign | role:coordinator |
| PATCH | /inspections/:id/schedule | #schedule | role:coordinator,inspector |
| POST | /inspections/:id/start | #start | role:inspector |
| PUT | /inspections/:id/form_response | form_responses#upsert | role:inspector |
| POST | /inspections/:id/photos | photos#create (presigned) | role:inspector |
| DELETE | /inspections/:id/photos/:pid | photos#destroy | role:inspector |
| POST | /inspections/:id/submit | #submit | role:inspector |
| POST | /inspections/:id/approve | #approve | role:manager |
| POST | /inspections/:id/reject | #reject | role:manager |
| GET | /inspections/:id/report | reports#show (signed URL) | scoped |
| GET | /inspections/:id/calendar | #calendar | staff, inspector |
| GET | /agencies · POST /agencies | agencies# | role:org_admin |
| POST | /agencies/:id/agency_users | agency_users#create | role:org_admin |
| GET | /invoices · POST /invoices/:id/send | invoices# | staff, agency(own) |
| POST | /webhooks/stripe | webhooks/stripe#create | public (sig-verified) |
| GET | /dashboard | dashboard#show | staff |

---

## 5. Design System

Direction: **editorial, linear, restrained.** White canvas, warm-neutral panels, hairline rules, one saturated brand-red accent per screen. Red is earned (primary action / active nav), never an ambient wash — the deliberate inverse of the current marketing site's red-heavy density. Status is communicated with a single colored dot + label, not filled rows. Cards are bordered, not shadowed.

### 5.1 Color tokens (shadcn CSS variables — light)

Put this in `app/globals.css`. HSL triplets are the shadcn convention; hex given for reference.

```css
:root{
  --background: 0 0% 100%;        /* #FFFFFF canvas */
  --foreground: 0 0% 4%;          /* #0A0A0A text */
  --card: 0 0% 100%;
  --card-foreground: 0 0% 4%;
  --popover: 0 0% 100%;
  --popover-foreground: 0 0% 4%;
  --primary: 356 77% 50%;         /* #E11D2A brand red */
  --primary-foreground: 0 0% 100%;
  --secondary: 30 6% 96%;         /* #F5F5F4 warm stone */
  --secondary-foreground: 0 0% 9%;
  --muted: 30 6% 96%;             /* #F5F5F4 */
  --muted-foreground: 25 6% 32%;  /* #57534E secondary text */
  --accent: 30 6% 96%;
  --accent-foreground: 0 0% 9%;
  --destructive: 0 74% 42%;       /* #B91C1C — reject/void ONLY */
  --destructive-foreground: 0 0% 98%;
  --border: 20 6% 90%;            /* #E7E5E4 hairline */
  --input: 20 6% 90%;
  --ring: 356 77% 50%;            /* focus = primary */
  --radius: 0.5rem;               /* buttons/inputs; cards use rounded-lg (0.625rem) */
}
```

Dark mode is out of scope for MVP; ship light only. Do not add a theme toggle.

**Status palette** — separate design tokens (not shadcn semantic vars). Status color justifies its own hue because it encodes real state; this does not violate the "one red accent" rule (the accent rule governs brand/primary chrome; a rejected inspection legitimately uses destructive red).

| Status | Dot hex | Meaning |
|---|---|---|
| submitted / unassigned | `#A8A29E` stone-400 | Not yet actioned |
| assigned | `#78716C` stone-500 | Inspector set |
| scheduled | `#2563EB` blue-600 | Date set |
| in_progress | `#0891B2` cyan-600 | On site |
| submitted_for_review | `#D97706` amber-600 | Awaiting manager |
| approved / delivered | `#059669` emerald-600 | Done |
| rejected / declined / cancelled | `#B91C1C` red-700 | Needs attention / dead |

Discipline rule for the build: **exactly one `bg-primary` element per screen** (the main CTA, or the active nav item when no CTA is present). Everything else is foreground/background/muted. Reviewers should reject any screen with two red fills.

### 5.2 Typography

Load via `next/font` (self-hosted, no layout shift). Three roles:

| Role | Family | Fallback | Use |
|---|---|---|---|
| Display | **Fraunces** (opsz, editorial serif) — or Newsreader | Georgia, serif | Page titles (h1), large stat numbers |
| UI / body | **Inter** — or Geist | system-ui, sans-serif | Everything else |
| Mono | **Geist Mono** — or JetBrains Mono | ui-monospace | IDs (`WMN-…`, `INV-…`), timestamps, data |

**Type scale** (rem / px @16):

| Token | Size | Weight | Tracking | Use |
|---|---|---|---|---|
| display-lg | 1.875rem/30 | 600 | -0.02em | h1 page titles (serif) |
| display-md | 1.75rem/28 | 600 | -0.02em | detail h1 (serif) |
| stat | 2.125rem/34 | 600 | -0.01em | dashboard numbers (serif) |
| title | 0.9375rem/15 | 600 | — | card/section headers |
| body | 0.8125rem/13 | 400/500 | — | default UI text |
| label | 0.75rem/12 | 600 | — | field labels |
| eyebrow | 0.6875rem/11 | 600 | 0.14em, uppercase | section eyebrows (muted-fg) |
| mono-sm | 0.75rem/12 | 400 | — | IDs, timestamps |

### 5.3 Spacing, radius, borders, motion

- Spacing scale: 4-based (4, 8, 12, 14, 16, 20, 24, 28, 32). Page padding 28–32px; card padding 18–22px; list-row padding 14×18px.
- Radius: buttons/inputs 8px (`--radius`), cards/panels 10px (`rounded-lg`), pills 999px, dots 50%.
- Borders: all structure is a 1px `--border` hairline. No shadows on cards. Shadow only on toasts and popovers/dialogs (shadcn default).
- Layout: centered column, `max-width: 1180px`. Content max-width 780px on detail/form views. Left-aligned throughout.
- Motion: functional only, 150–200ms ease-out on hover/press/nav. Respect `prefers-reduced-motion` (disable transitions). No decorative animation — extra motion reads as AI-generated and is explicitly unwanted.

### 5.4 shadcn/ui setup

`components.json`: `style: new-york`, `baseColor: stone`, `cssVariables: true`, `rsc: true`, `tailwind.prefix: ""`, iconLibrary: `lucide`.

Install these primitives: `button`, `input`, `textarea`, `select`, `label`, `card`, `badge`, `dialog`, `dropdown-menu`, `table`, `tabs`, `toast` (or `sonner`), `avatar`, `separator`, `skeleton`, `tooltip`, `checkbox`, `calendar` + `popover` (date picking), `command` (optional, agency picker). Extend `button` with a `size="sm"` and keep the default variants; add no custom variants beyond what §6 needs. Icons: lucide-react, 15–17px, `strokeWidth={2}`.

---

## 6. Status Machine — the shared contract

This is the single source of truth for both UI and backend. Status is **stored, never derived**; any O(n) recompute is forbidden. Implement server-side with AASM (or `state_machines`); each transition fires the job(s) in §9.

```
unassigned ──assign──▶ assigned ──schedule──▶ scheduled ──start──▶ in_progress
                                                                     │
                                              submit_for_review ◀────┘
                                                     │
                              ┌──────approve─────────┼──────reject──────┐
                              ▼                                          ▼
                         approved ──(auto)──▶ delivered            in_progress
                                                                 (rework loop)
cancelled: reachable from any pre-delivered state.
```

Transition table (who + guard + side effects):

| From → To | Trigger | Actor | Guard | Side effects |
|---|---|---|---|---|
| unassigned → assigned | assign | coordinator | inspector present | timeline: "Assigned to {name}" |
| assigned → scheduled | schedule | coordinator/inspector | datetime present | timeline; enqueue reminder T-24h |
| scheduled → in_progress | start | inspector (own) | — | timeline |
| in_progress → submitted_for_review | submit | inspector (own) | ≥1 photo; required form fields complete | timeline |
| submitted_for_review → approved → delivered | approve | manager | — | GenerateReportPdf → Deliver → CreateInvoice (§9) |
| submitted_for_review → in_progress | reject | manager | note present | store note; timeline: "Rejected — {note}" |
| any(pre-delivered) → cancelled | cancel | coordinator/admin | — | timeline; cancel pending reminder |

UI treatment: each status maps to the dot color in §5.1. `approved` is a transient internal state — the UI shows `delivered` once the pipeline completes; if generation fails, the inspection **holds at `approved` and never auto-advances without a PDF** (see §9 failure modes) and the manager is alerted.

---

## 7. Layout & Navigation

### App shell
Sticky top bar (56px, hairline bottom): brand mark (22px red square with an 8px black inner square) + wordmark "WINDMITIGATION.NETWORK" (`.network` in primary) + "Inspection Operations" sublabel · right side: current user name/sublabel. In production the role is derived from the session, not a switcher; the prototype's role toggle is a demo affordance only and must not ship.

Left nav (210px, hairline right), role-scoped:

| Role | Items |
|---|---|
| Agency | Dashboard · Request inspection · My inspections · Invoices |
| Coordinator/Admin | Dashboard · Requests · Dispatch · Agencies · Calendar |
| Inspector | Today |
| Manager | Review queue |

Active nav item: white bg, foreground text, `inset 2px 0 primary` left rule (not a red fill). Nav item default: muted-foreground; hover: muted bg.

### Three surfaces
- **Agency & Staff:** desktop-first, sidebar layout, content max-width 1180.
- **Field (inspector):** phone-first / installable PWA. Large tap targets (min 44px), single-column, bottom-anchored primary actions, camera-forward. On desktop it renders as a centered narrow column.

### Responsive
- ≥1024px: sidebar + content.
- 768–1023px: collapsible sidebar (icon rail), content full width.
- <768px: sidebar becomes a top sheet/drawer; the field surface is designed for this width first. Stat grids collapse 3→1; two-column meta/detail grids collapse to one.

---

## 8. Screen Specs

Template per screen: **Route · Access · Purpose · Layout · Data · States · Actions · Copy.** All routes under the App Router group in §10.

### 8.1 Agency — Dashboard
- Route `/(agency)/dashboard` · Access agency
- Purpose: at-a-glance status + one-tap request.
- Layout: PageHeader (eyebrow=agency name, title="Dashboard", primary CTA "Request inspection") → 3 stat cards (Open inspections, Delivered all-time, Reports this week) → "Recent activity" card = last 5 inspection rows.
- Data: `GET /inspections?scope=agency` (derive stats client-side or from `/dashboard` if extended for agencies).
- States: loading = skeleton stat cards + 5 skeleton rows; empty = "No inspections yet. Request your first — reports usually arrive within 24 hours." with the CTA.
- Actions: CTA → new request; row → detail.
- Copy: sub = "Request an inspection and the office handles assignment, scheduling, and delivery. No phone calls."

### 8.2 Agency — Request inspection
- Route `/(agency)/request/new` · Access agency
- Purpose: submit an intake request.
- Layout: single card, max-width 620. Fields: Property address; City (select: Cape Coral, Fort Myers, Naples, Punta Gorda — extend to full service-county list as data); Homeowner name; Homeowner email; **Inspection types** (multi-select chips showing `{label} · ${price}`); Preferred dates (free text or date-range picker); Notes. Footer: live count + estimated total, primary "Submit request".
- Data: `POST /inspection_requests` with `{ property, homeowner, requested_types[], preferred_dates, notes }`. Server dedupes/creates property + homeowner.
- Validation: address + homeowner name + ≥1 type required; email format if present. Disable submit until valid.
- States: submitting = button spinner; success = toast "Request submitted — the office will schedule it", redirect to dashboard; error = inline field errors from envelope + non-blocking toast.
- Copy: sub = "Enter the property and homeowner. We assign an inspector and deliver the report to all parties, usually within 24 hours."

### 8.3 Agency — My inspections
- Route `/(agency)/inspections` · Access agency
- Purpose: full history + status.
- Layout: PageHeader + one card of inspection rows (id · type · address · homeowner · StatusDot · chevron). Add a status filter (Tabs or Select) when list > ~15.
- Data: `GET /inspections?scope=agency` (cursor-paginated).
- States: loading skeleton rows; empty as 8.1.
- Actions: row → detail.

### 8.4 Agency — Inspection detail
- Route `/(agency)/inspections/[id]` · Access agency(own)
- Purpose: status, delivered report, timeline.
- Layout: back link → header (id eyebrow, "{Type} Inspection" serif, address w/ pin, StatusDot) → 2-col meta grid (Homeowner, Agency, Inspector, Scheduled, Fee, County) → **Report card** (only if delivered): "Report delivered" + filename (mono) + "Download" (signed URL) → "Captured on site" (read-only form answers + photo thumbnails) → Timeline.
- Data: `GET /inspections/:id`, `GET /inspections/:id/report` (lazy, on download).
- States: report card hidden until `delivered`; if not delivered, show a quiet line "Report will appear here once the inspection is approved."

### 8.5 Agency — Invoices
- Route `/(agency)/invoices` · Access agency(own)
- Layout: PageHeader + table (Invoice id mono · Mode · Amount · Status pill). Status pill colors: paid=emerald tint, sent=amber tint, void=muted.
- Data: `GET /invoices?scope=agency`.
- Copy: sub = "Fixed-rate and commission billing are generated automatically on report delivery."

### 8.6 Coordinator — Dashboard
- Route `/(staff)/dashboard` · Access staff
- Layout: PageHeader → 3 stats (Pending requests, Awaiting assignment, Active inspections) → **alert card** "New requests need triage" (only if pending>0, CircleAlert in primary) listing pending requests → "Active inspections" card (unassigned + assigned + scheduled + in_progress rows).
- Data: `GET /dashboard`.
- Actions: pending row → Requests; active row → Dispatch detail.

### 8.7 Coordinator — Requests (triage)
- Route `/(staff)/requests` · Access role:coordinator
- Purpose: accept (spawns one inspection per type) or decline.
- Layout: one card per pending request: agency name, address · homeowner, type chips + preferred-date chip, quoted note, right-aligned "Decline" (danger, needs reason) + "Accept" (primary).
- Data: `GET /inspection_requests?status=submitted`; `POST …/accept`, `POST …/decline`.
- Accept: server creates N inspections (`unassigned`), marks request `accepted`. Decline: opens a small reason field, then `POST …/decline`.
- States: empty = "No pending requests. New agency submissions land here."
- Toasts: "Accepted — {n} inspection(s) created" / "Request declined".

### 8.8 Coordinator — Dispatch
- Route `/(staff)/dispatch` (+ `/[id]`) · Access role:coordinator
- Purpose: assign + schedule.
- Layout (list): card of rows for `unassigned|assigned|scheduled|in_progress`. Detail reuses the shared Inspection Detail (§8.13) with the **Assign & schedule panel**: inspector Select + datetime field + "Confirm". Assigning fires `assign`; adding a datetime fires `schedule`.
- Data: `PATCH …/assign`, `PATCH …/schedule`.
- Empty: "Nothing to dispatch right now."

### 8.9 Coordinator — Agencies
- Route `/(staff)/agencies` · Access role:org_admin (visible-but-readonly for coordinator, or hidden — pick org_admin-only for MVP)
- Layout: rows of agency name · type · billing chip. "Add agency" (org_admin) opens a dialog (name, type, billing mode, commission rate if commission, primary contact email → invites first agency_user).
- Data: `GET/POST /agencies`, `POST /agencies/:id/agency_users`.

### 8.10 Coordinator — Calendar
- Route `/(staff)/calendar` · Access staff
- Purpose: scheduled inspections by day/inspector.
- Layout: week view; columns = inspectors, rows = time, blocks = scheduled inspections (id, type, city). Click → detail.
- Data: `GET /inspections?status=scheduled` (+ date range); or `GET /inspections/:id/calendar` feed.
- MVP acceptable fallback: a simple grouped-by-date list if a full calendar grid is over-budget for milestone 1 — note which was shipped.

### 8.11 Inspector — Today
- Route `/(field)/today` · Access role:inspector
- Purpose: the assigned queue.
- Layout: PageHeader (eyebrow = "{name} · {license}") → stacked cards: id mono, type, address w/ pin, scheduled time in blue if set, StatusDot + arrow. Phone-first spacing.
- Data: `GET /inspections?scope=inspector&status=assigned,scheduled,in_progress`.
- Empty: "No assigned inspections. New assignments appear here."

### 8.12 Inspector — Field detail (start → form → photos → submit)
- Route `/(field)/inspections/[id]` · Access role:inspector(own)
- Purpose: perform + submit. Progressive by status.
  - `scheduled`: single panel "Ready to begin the on-site inspection." + "Start inspection" (→ `start`).
  - `in_progress`: (a) **Form panel** — `DynamicFormRenderer` reading the active `inspection_form_template.schema` for the type; wind_mitigation shows the 7-feature `PLACEHOLDER` schema (§11) with a "best-guess schema · placeholder" badge; autosave each change via `PUT …/form_response`. (b) **Photos panel** — thumbnails w/ delete, caption input + "Add photo"; each add hits `POST …/photos` (presigned S3 direct upload, then attach; capture geotag). (c) **Submit panel** — "Submit for review", disabled until ≥1 photo (+ required form fields).
- Data: `PUT …/form_response`, `POST/DELETE …/photos`, `POST …/submit`.
- States: upload in-flight = thumbnail skeleton; upload error = retryable tile with message "Upload failed — tap to retry."
- Field UX: large controls; native camera on mobile (`capture` input). Autosave is silent; show a subtle "Saved" only on explicit submit.

### 8.13 Manager — Review queue + review detail
- Route `/(staff)/review` (list) → shared detail `/[id]` · Access role:manager
- Purpose: quality gate.
- Layout (list): cards for `submitted_for_review` (id, type, address, photo count, inspector) → arrow; below, "Recently delivered" (last 3). Detail reuses Inspection Detail with the **Manager review panel**: "Approve & deliver" (primary) + "Reject" (danger). Reject expands a reason textarea → "Send back".
- Data: `POST …/approve`, `POST …/reject`.
- Approve copy line: "Approving generates the PDF, delivers it to the homeowner and agency, and creates the invoice."
- Toasts: "Approved — report delivered, invoice created" / "Sent back to inspector".
- Empty: "Nothing awaiting review."

### 8.14 Shared — Inspection Detail (adapts by role)
The canonical detail component used by agency/dispatch/review. Sections in order: back link → header (id, "{Type} Inspection", address, StatusDot) → meta grid → **rework banner** (destructive-tinted, only when `in_progress` and a rejection note exists: "Sent back: {note}") → role action panel (Coordinator=assign/schedule; Inspector=start/form/photos/submit; Manager=approve/reject) → report card (if delivered) → "Captured on site" (form answers + photos, read-only) → Timeline (dotted vertical, each event = label + mono timestamp).

---

## 9. Background Jobs (Solid Queue)

| Job | Trigger | ~Runtime | Failure mode |
|---|---|---|---|
| GenerateReportPdfJob | inspection → approved | 3–8s | retry 3× backoff; on final fail, alert manager, **hold at `approved`** (never `delivered` without a PDF) |
| DeliverReportJob | report generated | 1–3s | retry; per-recipient log in `reports.delivered_to`; partial success re-enqueues only failed recipients |
| CreateInvoiceJob | inspection → delivered | <1s | idempotent on `inspection_id` (never double-bill) |
| SendInvoiceEmailJob | invoice → sent | 1–2s | provider retry |
| StripeWebhookJob | webhook received | <1s | idempotent via `webhook_events` unique key |
| InspectionReminderJob | scheduled_at − 24h | <1s | skip if cancelled; SMS + email |
| PhotoThumbnailJob | photo uploaded | 1–2s | non-blocking; original always retained |

All jobs `includes` associations to avoid N+1 (Bullet on in dev).

---

## 10. Frontend Architecture

**Structure (App Router, route groups by surface):**
```
app/
  (marketing)/login/page.tsx        # login entry only; public site stays on current CMS at MVP
  (agency)/layout.tsx  dashboard/  request/new/  inspections/[id]/  invoices/
  (staff)/layout.tsx   dashboard/  requests/  dispatch/[id]/  agencies/  calendar/  review/[id]/
  (field)/layout.tsx   today/  inspections/[id]/{form,photos,review}
  api/… (only if using route handlers as a thin proxy; otherwise call Rails directly)
components/
  ui/*            # shadcn primitives
  domain/*        # StatusDot, InspectionRow, PageHeader, MetaGrid, Timeline,
                  # DynamicFormRenderer, PhotoGrid, PhotoCapture, AssignSchedulePanel,
                  # ReviewPanel, ReportCard, EmptyState, AppShell, SideNav
lib/
  api.ts          # typed fetch client; attaches session cookie; parses error envelope
  auth.ts         # session/role helpers (server)
  types.ts        # shared domain types mirroring the API
  status.ts       # STATUS map (label+color) + transition guards (client mirror of §6)
```

**Data & auth**
- Server Components fetch on the server with the forwarded HTTPOnly session cookie; Client Components handle interaction and call the typed client in `lib/api.ts`.
- Session: first-party HTTPOnly, Secure, SameSite=Lax cookie shared between Next and Rails on a common parent domain; CSRF token enforced on mutations. No JWT at MVP.
- Every mutation goes through `lib/api.ts`, which unwraps `{ error: { code, message, details } }` into typed field errors for forms and a toast for the rest.
- Role gating in layouts: `(agency)`, `(staff)`, `(field)` layouts assert the session role and redirect on mismatch — defense in depth on top of Pundit.

**Forms:** react-hook-form + zod schemas that mirror server validation; inline errors under fields; disabled submit until valid; pending state on submit.

**Photo upload:** request a presigned S3 URL from `POST /inspections/:id/photos` (or a dedicated presign endpoint), PUT the file directly to S3, then confirm to attach. Optimistic thumbnail with retry on failure. `capture="environment"` on mobile for direct camera.

**State:** local component state + server refetch after mutations (or React Query/SWR if you prefer cache+revalidate — acceptable, keep it thin). No global store needed. **No localStorage/sessionStorage.**

**Quality floor (enforced in review):** responsive to 375px; visible keyboard focus (the `--ring`); `prefers-reduced-motion` disables transitions; all interactive elements ≥44px on the field surface; color contrast ≥4.5:1 for text (verify muted-foreground on white and on muted); every icon-only button has an aria-label; forms are label-associated.

---

## 11. Placeholders (wire as data, not logic)

- **`PLACEHOLDER` inspection prices** — seed values, all overridable in `inspection_type_configs`/pricing: wind_mitigation $175 (public), four_point $125, roof_condition $150, general_home $350, hoa_master_wind $450, wind_type_ii $225, wind_type_iii $275. Only wind_mitigation is confirmed. Replace on receipt of the price sheet.
- **`PLACEHOLDER` wind-mitigation form schema** — a best-guess 7-feature set stored as `inspection_form_templates` v1, NOT the certified OIR-B1-1802 layout: building_code, roof_covering (product approval), deck_attachment (A–D), roof_wall (toe-nail/clips/single/double wrap), roof_geometry (hip/flat/other), swr (yes/no), opening_protection (all-or-nothing). The renderer is schema-driven, so replacing this with the certified form is a new template version row. Build 4-point and roof-condition schemas the same way once their fields are provided; until then they capture free-form notes + photos.
- **Service counties** — the request-form city list is a stub; back it with the full county/city list from the marketing site (Lee, Collier, Charlotte, Sarasota, Manatee, DeSoto, Hendry, Glades, Martin, Orange, Polk, Monroe, Dade, Broward, Palm Beach, Hillsborough, Indian River, St. Lucie, Okeechobee, Brevard).

---

## 12. Build Sequence (each milestone shippable + tested)

1. **Foundation.** Rails app (API mode), Postgres, Solid Queue/Cache, Propshaft; Next app, Tailwind, shadcn init (§5.4), fonts, `globals.css` tokens, AppShell + SideNav + role layouts. Seed `organization` (WMN) + 2 offices. OmniAuth (Google + GitHub) for staff and agency, shared-cookie session. *Tests:* auth request specs, session round-trip.
2. **Agencies & partners.** `agencies`, `agency_users`; org-admin onboarding + agency invite; Agencies screen (§8.9). *Tests:* policies (agency isolation), create/invite request specs.
3. **Request → inspection.** `properties`, `homeowners`, `inspection_requests`, `inspections`; agency Request form (§8.2) + Requests triage (§8.7) with accept/decline spawning inspections. *Tests:* accept spawns N inspections; agency sees only own.
4. **Dispatch.** assign + schedule transitions + Dispatch screen (§8.8) + Calendar (§8.10, list fallback acceptable). InspectionReminderJob. *Tests:* transition guards, scoping.
5. **Field capture.** `inspection_form_templates` (seed wind-mit v1 `PLACEHOLDER`), `inspection_form_responses`, `inspection_photos` (presigned S3); Field surface (§8.11–8.12): start/form/photos/submit; DynamicFormRenderer. *Tests:* submit guard (≥1 photo + required fields), upsert idempotency, upload presign.
6. **Review → delivery → invoice.** approve/reject; GenerateReportPdfJob (wind-mit PDF first — the highest-risk piece, see §13), DeliverReportJob, CreateInvoiceJob; Manager queue (§8.13); report card + signed download (§8.4). Postmark transactional email + domain auth. *Tests:* approve fires full pipeline; failure holds at `approved`; invoice idempotent.
7. **Billing surface + Stripe.** `invoices`, `payments`, webhook controller w/ idempotency ledger; Invoices screens (§8.5); Stripe Checkout/Portal + send-invoice. *Tests:* webhook idempotency, double-bill prevention.
8. **Polish + quality floor.** Empty/loading/error states across all screens, responsive pass to 375px, a11y pass (§10), Sentry + lograge + PostHog. System specs for the three critical journeys: agency request→delivery, inspector field→submit, manager approve→invoice.

---

## 13. Assumptions, Risks & Open Questions

- **White-label is the pricing fork (unresolved).** Phase 4 of the original scope is a reseller/licensing platform selling this to *other* inspection companies. MVP is built multi-tenant-ready (`organization_id` everywhere) so that future is cheap, but the subscription/coupon/wallet/commission/channel-partner machinery is **not** built. Do not build it. Confirm day-one vs. someday before Phase 2 — it changes timeline and price materially.
- **"Oracle" (unresolved).** The original scope says twice to "push converted client details to Oracle." Meaning unknown (Oracle CRM/NetSuite? a customer system? placeholder?). Do not build an integration on a guess. Flag and wait.
- **OIR-B1-1802 fidelity is legal, not cosmetic (highest single risk).** The generated wind-mit PDF must match the current certified form closely enough that insurers accept it, with color photos in one PDF. The exact current form version + a known-good sample report are required inputs before GenerateReportPdfJob is finalized. Milestone 6 ships against the `PLACEHOLDER` schema and is revised on receipt.
- **Pricing table incomplete.** Only wind_mitigation ($175) is confirmed; the rest are `PLACEHOLDER` seed values.
- **Email deliverability underpins the 24-hour promise.** Postmark/Resend sender-domain auth (SPF/DKIM) is a launch blocker — reports in spam is a silent failure of the core promise.
- **Do not ship the prototype's role switcher.** Role comes from the session; the toggle is a demo affordance only.

---

## 14. Model Routing (Claude Code)

**How to read this section.** A model cannot silently reprogram which model answers by reading a doc — model selection is a client/config control (`/model`, `--model`, `ANTHROPIC_MODEL`, settings, subagent frontmatter), and autonomous mid-session self-switching is a known defect, not a feature to rely on. Switching also reprocesses history without cache, so it is not free. Therefore this project routes by **milestone boundary**, not per-task, using two supported mechanisms: (A) an explicit **checkpoint** the agent surfaces to the user, and (B) optional **subagent/opusplan** config that automates the split. Prefer A; it degrades gracefully on any plan. Use B if the operator wants hands-off routing.

### 14.1 Routing table (milestones from §12)

Default driver is **Sonnet** (Sonnet 5 as of 2026-06-30). Escalate to **Opus 4.8 at `xhigh` effort** only for the load-bearing, high-consequence work. Rationale: Opus leads on coding/agentic reasoning by a few points; Sonnet is ~40% cheaper and ties on routine work. The spec is precise enough that Sonnet executes the bulk without the premium.

| Milestone / component | Model | Effort | Why |
|---|---|---|---|
| M1 Foundation — architecture scaffold, route groups, auth/session wiring | **Opus 4.8** | xhigh | Early architecture calls propagate; get them right once. |
| M1 remainder — shadcn init, tokens, fonts, shell/nav | Sonnet | high | Mechanical; spec is exact. |
| M2 Agencies & partners — CRUD + invites | Sonnet | high | Standard. |
| M2 **Pundit scoping + tenancy isolation** | **Opus 4.8** | xhigh | Security-critical; a scoping miss leaks data across agencies/tenants. |
| M3 Request→inspection — forms, triage, spawn | Sonnet | high | Standard, but review the accept-spawns-N logic. |
| **§6 Status state machine (build before M3 screens)** | **Opus 4.8** | xhigh | The spine; cross-cutting; subtle bugs are expensive. |
| M4 Dispatch — assign/schedule, calendar, reminder job | Sonnet | high | Transitions already specified by §6. |
| M5 Field capture — form renderer, presigned uploads | Sonnet | high | Standard once §6 exists. |
| **M6 Report pipeline — GenerateReportPdf (OIR-B1-1802)** | **Opus 4.8** | xhigh | Highest single risk (§13); legal fidelity. |
| **M7 Stripe webhooks + billing idempotency** | **Opus 4.8** | xhigh | Money correctness; double-bill prevention. |
| M8 Polish, states, a11y, responsive, system specs | Sonnet | high | Volume work. |
| Exploration / codebase search subagents | Haiku | — | Grep-style; quality delta negligible, cost 5× lower. |

Fable 5 is not used on this project — it is frontier-tier ($10/$50) and unjustified here.

### 14.2 Checkpoint protocol (mechanism A — required behavior)

At the start of each milestone, the agent must **pause and state the recommended model + effort** for that milestone from §14.1 before writing code, in one line, e.g.:

> `▶ Milestone 6 (report pipeline) — recommend Opus 4.8 at xhigh. Run '/model opus' and set effort xhigh, then say continue. Or tell me to proceed on the current model.`

Then wait for the operator. The agent does not switch models itself and does not proceed silently on a model that contradicts the table. Within a milestone, do not thrash models — batch the Opus work, since switching mid-task breaks prompt caching. This behavior belongs in `CLAUDE.md` (repo root) so it is loaded and enforced every session; a companion `CLAUDE.md` is provided.

### 14.3 Automated routing (mechanism B — optional)

For hands-off operation, use either:
- **`opusplan` alias** — Opus during plan mode, auto-switching to Sonnet at execution. Good default for the architecture-heavy milestones (M1, §6, M6, M7): plan on Opus, implement on Sonnet. Caveat: `opusplan` may not receive the 1M context window a plain `opus` selection gets on Max/Team/Enterprise — verify with `/context` if loading the whole codebase matters.
- **Pinned subagents** — define subagents whose frontmatter pins model + effort, and delegate the hard milestones to them. Set a Sonnet default for inherited subagents via `CLAUDE_CODE_SUBAGENT_MODEL`; pin the hard ones per-agent. Example frontmatter:

```markdown
---
name: state-machine
description: Builds and tests the §6 inspection status state machine (AASM).
model: claude-opus-4-8
effort: xhigh
---
```
```markdown
---
name: billing-webhooks
description: Stripe webhook idempotency, invoice/payment correctness (M7).
model: claude-opus-4-8
effort: xhigh
---
```
```markdown
---
name: screens
description: Implements React screens from §8 against the design system (§5).
model: claude-sonnet-5
effort: high
---
```

Effort in subagent frontmatter overrides the session level while that subagent runs. Keep the main session on the checkpoint protocol even when using subagents, so the operator retains control of the coordination model.

---

## Appendix A — Environment Variables

**Rails (secret unless noted):** DATABASE_URL · RAILS_MASTER_KEY · STRIPE_SECRET_KEY · STRIPE_WEBHOOK_SECRET · POSTMARK_API_TOKEN · TWILIO_ACCOUNT_SID · TWILIO_AUTH_TOKEN · TWILIO_FROM · AWS_ACCESS_KEY_ID · AWS_SECRET_ACCESS_KEY · AWS_S3_BUCKET (public) · AWS_REGION (public) · GOOGLE_OAUTH_CLIENT_ID/SECRET · GITHUB_OAUTH_CLIENT_ID/SECRET · GOOGLE_MAPS_API_KEY · APP_HOST (public) · SENTRY_DSN
**Next (`.env.local`):** NEXT_PUBLIC_API_BASE_URL (public) · NEXT_PUBLIC_APP_HOST (public) · SENTRY_DSN · NEXT_PUBLIC_SENTRY_DSN (public)
**Deploy:** FLY_API_TOKEN · VERCEL_TOKEN · POSTHOG_API_KEY

## Appendix B — Deployment

Frontend on Vercel; Rails + Solid Queue worker on Fly.io (web + worker processes, one app); Postgres on Fly or Neon (hosted, not self-managed at MVP). Migration order follows the §3 table order. Seed: 1 organization (WMN), 2 offices, form template v1 for wind_mitigation/four_point/roof_condition, `PLACEHOLDER` price list. Post-deploy: register Stripe webhook URL, verify Postmark sender domain (load-bearing), set OAuth redirect URIs for both hosts, DNS `app.` → Vercel and API subdomain → Fly, and set the shared cookie parent domain explicitly.

## Appendix C — Hosting & Observability defaults
Sentry (front + back), lograge structured logs on Rails, uptime via Better Stack, product analytics via PostHog. ADRs in `docs/decisions/NNNN-title.md` (Context / Decision / Consequences, ≤3 paragraphs) for any deviation from these defaults.
