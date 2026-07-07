# Fires when an inspection enters `delivered` (spec §6, §9). Creates the invoice
# for the job at its snapshotted price/billing mode. MUST be idempotent on
# `inspection_id` — a redelivery or retry must never double-bill (spec §0, §9).
#
# Body lands in M7 (Stripe/billing, Opus @ xhigh). Stubbed until the invoices
# model exists.
class CreateInvoiceJob < ApplicationJob
  queue_as :default

  def perform(inspection)
    Rails.logger.info(
      "[CreateInvoiceJob] inspection=#{inspection.id} — billing lands in M7 " \
      "(idempotent on inspection_id; never double-bill)."
    )
    # M7: Invoice.find_or_create_by!(inspection:) { … }; enqueue SendInvoiceEmailJob.
  end
end
