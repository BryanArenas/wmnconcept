# A payment against an invoice (spec §3). Created by StripeWebhookJob when Stripe
# confirms a charge, or manually for cash/ach. The unique index on
# stripe_payment_intent_id is the double-bill backstop: a redelivered
# payment-succeeded event cannot create a second Payment.
class Payment < ApplicationRecord
  METHODS = %w[card cash ach].freeze

  belongs_to :organization
  belongs_to :invoice

  enum :method, {
    card: "card",
    cash: "cash",
    ach: "ach"
  }, prefix: :method, validate: true

  validates :amount_cents, presence: true,
                           numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :stripe_payment_intent_id, uniqueness: true, allow_nil: true

  def amount_dollars = amount_cents / 100.0
end
