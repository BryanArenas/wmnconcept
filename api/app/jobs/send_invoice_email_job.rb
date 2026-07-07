# Fires when an invoice is sent (spec §9). Emails the agency their pay link.
# The invoice is already marked `sent` + given its Stripe id by the controller;
# this job only handles delivery, so it is safe to retry.
class SendInvoiceEmailJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(invoice)
    pay_url = invoice.stripe_invoice_id.present? ? hosted_url(invoice) : "#"
    InvoiceMailer.with(invoice:, pay_url:).invoice_sent.deliver_now
  end

  private

  # The Stripe-hosted invoice page. With the stub id (dev/test) this is a
  # placeholder; the real hosted_invoice_url comes back on the Stripe invoice.
  def hosted_url(invoice)
    "https://invoice.stripe.com/i/#{invoice.stripe_invoice_id}"
  end
end
