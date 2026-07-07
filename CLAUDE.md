# CLAUDE.md — Wind Mitigation Network build

Source of truth: `wmn-build-spec.md`. Read it before building. This file holds only what must be enforced every session and the *why* behind it.

## Non-negotiables (from spec §0)

- **PKs:** UUID on anything reachable by URL/API; bigint on internal join tables. Not interchangeable.
- **Tenancy:** `organization_id` on every tenant-scoped table, enforced via query object / Pundit scope — never a bare `default_scope`. A scoping miss leaks data across agencies. Treat every list/show as scoped by default.
- **API:** versioned `/api/v1/`; cursor pagination on all index actions; error envelope `{ error: { code, message, details } }` on every non-2xx.
- **Status is a stored state machine (spec §6), never derived.** Build it (AASM) before the screens that depend on it. Transitions fire the jobs in §9; a failed report generation holds at `approved` and never auto-advances to `delivered` without a PDF.
- **Jobs:** Solid Queue. **Payments:** Stripe with idempotent webhooks (unique `webhook_events[provider,external_id]`); never double-bill.
- **Tests:** RSpec request spec on every controller action — happy path + auth failure + one edge. FactoryBot only; **fixtures forbidden.**
- **Migrations:** reversible via `change`; indexes in the same migration as the column.
- **Deviations** from spec defaults get a 3-paragraph ADR in `docs/decisions/NNNN-title.md` (Context / Decision / Consequences).

## Placeholders — wire as data, not logic (spec §11)

Inspection prices and the wind-mitigation form schema are `PLACEHOLDER`s. They live in config / template rows so they swap without code changes. Do **not** bake a guessed price or form field into a migration or into logic. Only `wind_mitigation = $175` is confirmed.

## Do not build (spec §13)

White-label / licensing / subscriptions / reseller machinery. "Oracle" integration. Both are unresolved — build so neither is foreclosed, build machinery for neither. Do not ship the prototype's role switcher; role comes from the session.

## Model routing (spec §14) — REQUIRED behavior

Default driver: **Sonnet**. Escalate to **Opus 4.8 at `xhigh`** only for the load-bearing milestones below.

**At the start of each milestone, pause and state the recommended model + effort in one line, then wait for the operator.** Do not switch models yourself; do not proceed silently on a model that contradicts the table. Example:

> `▶ Milestone 6 (report pipeline) — recommend Opus 4.8 @ xhigh. Run /model opus, set effort xhigh, then say continue — or tell me to proceed as-is.`

Within a milestone, do not thrash models — switching mid-task breaks prompt caching. Batch the Opus work.

| Work | Model @ effort |
|---|---|
| M1 architecture scaffold; §6 state machine; Pundit/tenancy; M6 report/PDF; M7 Stripe/billing | **Opus 4.8 @ xhigh** |
| Everything else (screens, CRUD, forms, seed, polish) | Sonnet @ high |
| Codebase exploration / search subagents | Haiku |

Optional hands-off automation: `opusplan` (Opus plans, Sonnet executes) for the architecture-heavy milestones, or pinned subagents (see spec §14.3). If using subagents, keep the main coordination session on this checkpoint protocol.

## Build order

Follow spec §12 milestones. One PR per milestone; run tests between. Do not one-shot the app. Build §6 (state machine), tenancy scoping, and billing first-and-carefully — those are the ones to review hardest. Do not run M5–M7 against real logic until the certified OIR-B1-1802 form and the price sheet arrive; until then they run against placeholders.
