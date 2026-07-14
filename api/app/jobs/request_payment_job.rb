# Fires when an inspection is scheduled (spec §6 schedule transition). Bills the
# job up front: creates the invoice (idempotently), moves it draft → sent, and
# emails the payer a pay link. Payment collection itself is a PLACEHOLDER until
# the live Stripe account lands (spec §11) — no real charge is taken here.
#
# Idempotent on inspection_id via Invoice.create_for, so a reschedule or a retry
# never creates a second invoice, and the later delivery-time CreateInvoiceJob
# finds this same invoice and no-ops.
class RequestPaymentJob < ApplicationJob
  queue_as :default

  def perform(inspection)
    invoice = Invoice.create_for(inspection)
    return unless invoice.payable? # already paid or voided — nothing to request

    invoice.mark_sent! if invoice.status == "draft"
    InvoiceMailer.with(invoice:, pay_url: PaymentLink.for(invoice)).invoice_sent.deliver_later
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.info("[RequestPaymentJob] invoice already exists for inspection=#{inspection.id}")
  end
end
