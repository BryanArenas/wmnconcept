# 0001 — Namespace the agency portal under `/agency/*`

## Context

Spec §10 lays out the frontend as three App Router route groups — `(agency)`,
`(staff)`, `(field)` — with pages like `(agency)/dashboard` and
`(staff)/dashboard`. In Next.js, a route group `(name)` organizes files and
layouts **without adding a URL segment**. That means `(agency)/dashboard` and
`(staff)/dashboard` both resolve to the same URL `/dashboard`, and
`(agency)/inspections/[id]` collides with `(field)/inspections/[id]`. Next.js
treats two pages resolving to one path as a build error, so the §10 tree cannot
be built verbatim. The three surfaces are genuinely separate (staff and agency
authenticate against different tables and never share a session), so the intent
is clearly three isolated surfaces, not one shared `/dashboard`.

## Decision

Keep the staff and field surfaces on the friendly, unprefixed URLs the spec
shows (`/dashboard`, `/requests`, `/dispatch`, `/today`, `/inspections/[id]`,
…), and move the external agency portal under a real `/agency/*` path segment
(`/agency/dashboard`, `/agency/request/new`, `/agency/inspections/[id]`,
`/agency/invoices`). The `(staff)` and `(field)` route groups are retained for
shared layouts; the agency surface uses an `app/agency/` segment with its own
`layout.tsx`. This resolves both collisions (`/dashboard` and
`/inspections/[id]`) while preserving per-surface layout isolation and role
gating. The `/agency` prefix also reads naturally for partners as a distinct
portal, consistent with the "agency portal is the wedge" framing in §1.

## Consequences

Agency URLs differ from the literal §10 paths by an `/agency` prefix; all agency
nav (`AGENCY_NAV`), links, and post-login redirects for agency users point at
the prefixed paths. Staff and field URLs are unchanged from the spec. If the
agency portal later needs to live on its own subdomain (e.g.
`partners.windmitigation.network`), the `/agency` segment maps cleanly to a host
split with no page moves. No backend/API routes are affected — this is purely a
frontend URL-structure decision.
