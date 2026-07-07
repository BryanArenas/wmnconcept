# Billing record for a delivered inspection (spec §3, §9). Created idempotently
# by CreateInvoiceJob — one per inspection (unique index + find_or_create) so a
# retry or redelivery never double-bills. Amount is computed by InvoiceAmount
# from the snapshotted price + agency billing mode (see ADR 0002).
#
# Lifecycle: draft → sent → paid | void. The Stripe send/collect path lands in M7.
class Invoice < ApplicationRecord
  STATUSES = %w[draft sent paid void].freeze

  belongs_to :organization
  belongs_to :agency
  belongs_to :inspection
  has_many :payments, dependent: :restrict_with_exception

  enum :billing_mode, {
    fixed_rate: "fixed_rate",
    commission: "commission"
  }, prefix: :billing, validate: true

  validates :amount_cents, presence: true,
                           numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :inspection_id, uniqueness: true

  scope :for_status, ->(s) { where(status: s) }

  def amount_dollars = amount_cents / 100.0

  # Lifecycle helpers (spec §3: draft → sent → paid | void). Kept explicit rather
  # than a state machine — the invoice has no guards/side-effect jobs of its own;
  # the money side effects live on Payment + the Stripe webhook path.
  def mark_sent!(stripe_invoice_id: nil)
    update!(status: "sent", stripe_invoice_id: stripe_invoice_id || self.stripe_invoice_id)
  end

  def mark_paid!
    update!(status: "paid")
  end

  def payable? = %w[draft sent].include?(status)
end
