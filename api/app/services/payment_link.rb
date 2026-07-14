# The URL a payer follows to settle an invoice. When Stripe is configured this
# is the Stripe-hosted invoice page; otherwise it's the app's own placeholder
# pay page (spec §11 — billing collection is a PLACEHOLDER until the live Stripe
# account lands, so the flow is exercisable end-to-end with no real charge).
module PaymentLink
  module_function

  def for(invoice)
    if StripeGateway.configured? && invoice.stripe_invoice_id.present?
      "https://invoice.stripe.com/i/#{invoice.stripe_invoice_id}"
    else
      "#{frontend_base}/pay/#{invoice.id}"
    end
  end

  def frontend_base
    ENV.fetch("FRONTEND_URL", "http://localhost:3000").chomp("/")
  end
end
