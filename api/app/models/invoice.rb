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

  DUE_IN = 14.days

  # Idempotent creation of the single invoice for an inspection (spec §0, §9):
  # unique index on inspection_id + find_or_create means a retry, a redelivery,
  # or the schedule-time and delivery-time paths both landing here never double
  # bill. Amount is snapshotted from the inspection price + agency billing mode
  # (ADR 0002). Callers rescue nothing — RecordNotUnique on a concurrent double
  # fire is handled by the job that calls this.
  def self.create_for(inspection)
    find_or_create_by!(inspection_id: inspection.id) do |invoice|
      invoice.organization = inspection.organization
      invoice.agency       = inspection.agency
      invoice.amount_cents = InvoiceAmount.for(inspection)
      invoice.billing_mode = inspection.agency.billing_mode
      invoice.status       = "draft"
      invoice.due_at       = DUE_IN.from_now
    end
  end

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
