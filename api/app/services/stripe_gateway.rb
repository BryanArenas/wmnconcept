# Boundary around the Stripe SDK (spec §9, M7). Everything Stripe-specific lives
# here so the rest of the app deals in our own models. Two env vars gate it:
#   STRIPE_SECRET_KEY   → real API calls (create invoice)
#   STRIPE_WEBHOOK_SECRET → signature verification on inbound webhooks
#
# When unconfigured (dev/test) it returns deterministic stub ids and parses
# webhook payloads without signature verification, so the whole billing + webhook
# idempotency path is exercisable without a live account.
module StripeGateway
  module_function

  def configured?
    ENV["STRIPE_SECRET_KEY"].present?
  end

  def webhook_verification?
    ENV["STRIPE_WEBHOOK_SECRET"].present?
  end

  # Creates a Stripe invoice for one of our invoices and returns its Stripe id.
  # The stub path (unconfigured) returns a stable id derived from our invoice id
  # so re-sends stay idempotent.
  def create_invoice(invoice)
    return "in_stub_#{invoice.id}" unless configured?

    require "stripe"
    customer = Stripe::Customer.create(
      email: invoice.agency.primary_contact_email,
      name: invoice.agency.name,
      metadata: { agency_id: invoice.agency_id }
    )
    Stripe::InvoiceItem.create(
      customer: customer.id,
      amount: invoice.amount_cents,
      currency: "usd",
      description: "Inspection #{invoice.inspection_id}"
    )
    stripe_invoice = Stripe::Invoice.create(
      customer: customer.id,
      collection_method: "send_invoice",
      days_until_due: 14,
      metadata: { invoice_id: invoice.id }
    )
    Stripe::Invoice.finalize_invoice(stripe_invoice.id)
    stripe_invoice.id
  end

  # Verifies + parses an inbound webhook. Returns a Hash with at least "id",
  # "type", and "data". Raises StripeGateway::VerificationError on a bad
  # signature. In dev/test (no webhook secret) it parses the JSON directly.
  def parse_webhook(payload:, signature:)
    if webhook_verification?
      require "stripe"
      begin
        event = Stripe::Webhook.construct_event(payload, signature, ENV["STRIPE_WEBHOOK_SECRET"])
        event.to_hash.deep_stringify_keys
      rescue Stripe::SignatureVerificationError, JSON::ParserError => e
        raise VerificationError, e.message
      end
    else
      JSON.parse(payload)
    end
  end

  class VerificationError < StandardError; end
end
