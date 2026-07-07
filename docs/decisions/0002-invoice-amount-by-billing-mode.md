# 0002 — Invoice amount by billing mode

## Context

`CreateInvoiceJob` fires when an inspection reaches `delivered` (spec §6/§9) and
must produce an invoice at the inspection's snapshotted `price_cents` and the
agency's `billing_mode`. The spec fixes the price snapshot and the two billing
modes (`fixed_rate`, `commission`, §3) but does **not** state the amount formula
for a commission-mode invoice — only that billing is "generated automatically on
report delivery" (§8.5) and that the job is "idempotent on `inspection_id`
(never double-bill)" (§9). Because this is a money path, the ambiguity has to be
resolved explicitly rather than guessed inline.

## Decision

The invoice `amount_cents` is computed by `InvoiceAmount.for(inspection)`:

- **fixed_rate** → the full inspection fee (`inspection.price_cents`). The agency
  is billed the inspection price directly.
- **commission** → the commission owed to the agency,
  `(price_cents * agency.commission_rate).round`, stored as a distinct invoice so
  the commission arrangement is auditable per inspection.

`billing_mode` is copied onto the invoice at creation so a later change to the
agency's mode never rewrites historical invoices. Idempotency is enforced two
ways: a unique DB index on `invoices.inspection_id`, and `find_or_create_by` in
the job — a retry or redelivery returns the existing invoice instead of billing
again. Invoices are created in `draft`; the Stripe send/collect path lands in M7.

## Consequences

The commission formula is an assumption made to unblock M6 and is flagged for
confirmation with the business (the same open pricing thread as §13). It is
isolated in one place (`InvoiceAmount`) and covered by tests, so correcting it on
receipt of the real commission terms is a one-file change with no schema impact.
Should commission billing later need both a client-facing charge and an agency
commission line, that becomes a second invoice/line-item type — the current
single-invoice-per-inspection unique constraint would be revisited at that point,
but nothing here forecloses it.
