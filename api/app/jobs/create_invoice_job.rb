# Fires when an inspection enters `delivered` (spec §6, §9). Ensures the invoice
# exists at its snapshotted price + the agency's billing mode. Idempotent on
# `inspection_id` (Invoice.create_for) — so when billing already happened at
# scheduling (RequestPaymentJob) this simply finds that invoice and no-ops, and
# a redelivery or retry never double-bills (spec §0, §9).
class CreateInvoiceJob < ApplicationJob
  queue_as :default

  def perform(inspection)
    Invoice.create_for(inspection)
  rescue ActiveRecord::RecordNotUnique
    # Concurrent fire already created it — idempotent by design, nothing to do.
    Rails.logger.info("[CreateInvoiceJob] invoice already exists for inspection=#{inspection.id}")
  end
end
