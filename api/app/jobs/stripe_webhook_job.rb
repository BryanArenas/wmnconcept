# Applies the side effects of a verified Stripe webhook (spec §9, M7). Enqueued
# by Webhooks::StripeController after the event is recorded in webhook_events.
#
# Idempotency is defence-in-depth (money correctness — never double-bill):
#   1. webhook_events unique (provider, external_id) — a redelivered event is
#      recorded once; this job returns early if already processed.
#   2. payments unique stripe_payment_intent_id — even two *distinct* events that
#      reference the same charge can create at most one Payment.
#
# Expected payload shape (Stripe event.to_hash):
#   data.object.metadata.invoice_id → our Invoice UUID (set at create_invoice)
#   data.object.payment_intent | data.object.id → the charge/intent id
#   data.object.amount_paid | amount_received | amount → cents (falls back to
#   the invoice amount)
class StripeWebhookJob < ApplicationJob
  queue_as :default

  PAYMENT_TYPES = %w[invoice.paid payment_intent.succeeded checkout.session.completed].freeze

  def perform(webhook_event_id)
    event = WebhookEvent.find(webhook_event_id)
    return if event.processed? # idempotent: side effects already applied

    type = event.payload["type"]
    apply_payment(event) if PAYMENT_TYPES.include?(type)

    event.mark_processed!
  end

  private

  def apply_payment(event)
    object    = event.payload.dig("data", "object") || {}
    invoice   = Invoice.find_by(id: object.dig("metadata", "invoice_id"))
    return log_missing(event) unless invoice

    intent_id = object["payment_intent"] || object["id"]
    amount    = object["amount_paid"] || object["amount_received"] ||
                object["amount"] || invoice.amount_cents

    ActiveRecord::Base.transaction do
      record_payment(invoice, intent_id, amount)
      invoice.mark_paid! unless invoice.status == "paid"
    end
  end

  def record_payment(invoice, intent_id, amount)
    Payment.find_or_create_by!(stripe_payment_intent_id: intent_id) do |p|
      p.organization = invoice.organization
      p.invoice      = invoice
      p.amount_cents = amount
      p.method       = "card"
      p.paid_at      = Time.current
    end
  rescue ActiveRecord::RecordNotUnique
    # A concurrent event with the same intent already recorded the payment —
    # idempotent by design, nothing to do.
    Rails.logger.info("[StripeWebhookJob] payment already recorded intent=#{intent_id}")
  end

  def log_missing(event)
    Rails.logger.warn(
      "[StripeWebhookJob] no invoice for event=#{event.external_id} " \
      "(metadata.invoice_id missing or unknown)"
    )
  end
end
