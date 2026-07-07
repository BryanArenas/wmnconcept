# Fires when an inspection enters `delivered` (spec §6, §9). Creates the invoice
# for the job at its snapshotted price + the agency's billing mode. Idempotent on
# `inspection_id` — a redelivery or retry must never double-bill (spec §0, §9).
#
# Idempotency is enforced two ways: find_or_create_by on inspection_id, and the
# unique DB index behind it (a concurrent double-fire raises RecordNotUnique,
# caught here). The invoice is created `draft`; the Stripe send/collect path
# (SendInvoiceEmailJob, webhooks) lands in M7.
class CreateInvoiceJob < ApplicationJob
  queue_as :default

  DUE_IN = 14.days

  def perform(inspection)
    Invoice.find_or_create_by!(inspection_id: inspection.id) do |invoice|
      invoice.organization = inspection.organization
      invoice.agency       = inspection.agency
      invoice.amount_cents = InvoiceAmount.for(inspection)
      invoice.billing_mode = inspection.agency.billing_mode
      invoice.status       = "draft"
      invoice.due_at       = DUE_IN.from_now
    end
  rescue ActiveRecord::RecordNotUnique
    # Concurrent fire already created it — idempotent by design, nothing to do.
    Rails.logger.info("[CreateInvoiceJob] invoice already exists for inspection=#{inspection.id}")
  end
end
