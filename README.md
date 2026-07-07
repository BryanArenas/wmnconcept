# Wind Mitigation Network

Multi-tenant-ready platform that runs the full third-party insurance-inspection
loop for Wind Mitigation Network LLC: agency requests → assignment & scheduling
→ field capture → manager review → PDF delivery → invoicing. The wedge is the
agency portal — "enter your client's info and we handle the rest."

**Source of truth:** [`wmn-build-spec.md`](./wmn-build-spec.md). Session
guardrails live in [`CLAUDE.md`](./CLAUDE.md). Architecture deviations are
recorded as ADRs in [`docs/decisions/`](./docs/decisions).

## Stack

| Layer | Tech |
|---|---|
| API | Rails 8 (API-only), PostgreSQL, Solid Queue/Cache/Cable, Puma |
| Web | Next.js 16 (App Router, TS), Tailwind v4, shadcn/ui (new-york/stone) |
| Auth | OmniAuth (Google + GitHub), first-party HTTPOnly shared-cookie session |

## Layout

```
api/   Rails 8 API — models, controllers, jobs, specs
web/   Next.js frontend — App Router route groups per surface (staff/field/agency)
docs/  decisions/  ADRs (Context / Decision / Consequences)
```

## Local development

Prerequisites: Ruby 3.3, Node 22, PostgreSQL 16.

```bash
# API (http://localhost:3001)
cd api
bundle install
bin/rails db:prepare db:seed
bin/rails server -p 3001

# Web (http://localhost:3000)
cd web
npm install
npm run dev
```

Copy `api/.env.example` → `api/.env` and `web/.env.example` → `web/.env.local`
and fill in credentials as needed. For local sign-in without live OAuth apps,
run the API with `OMNIAUTH_TEST_MODE=1` (development only) and visit
`/auth/google_oauth2/callback` to sign in as the seeded coordinator.

## Tests

```bash
cd api && bundle exec rspec        # request + model specs (FactoryBot, no fixtures)
cd web && npm run build && npm run lint
```

## Build status (spec §12 milestones)

- [x] **M1 — Foundation.** Rails API scaffold, Postgres, Solid stack; core
  tenancy (`organizations`, `offices`, `users`) with UUID/bigint PK split and
  `organization_id` scoping; `/api/v1` base with error envelope + cursor
  pagination; OmniAuth staff auth + shared-cookie session + CSRF; Next app,
  design tokens (§5), fonts, AppShell + SideNav + role-gated layouts.
- [ ] M2 — Agencies & partners
- [ ] M3 — Request → inspection
- [ ] M4 — Dispatch
- [ ] M5 — Field capture
- [ ] M6 — Review → delivery → invoice
- [ ] M7 — Billing + Stripe
- [ ] M8 — Polish + quality floor
