# Referral partner (spec §2, §3): insurance/real-estate agents who submit
# inspection requests through the portal. Billed either at a fixed rate or a
# commission on the fee.
class Agency < ApplicationRecord
  # `type` is a plain enum column here, not Rails STI.
  self.inheritance_column = nil

  belongs_to :organization
  has_many :agency_users, dependent: :restrict_with_exception
  has_many :inspection_requests, dependent: :restrict_with_exception
  has_many :inspections, dependent: :restrict_with_exception

  enum :type, {
    insurance: "insurance",
    real_estate: "real_estate",
    other: "other"
  }, validate: true

  enum :billing_mode, {
    fixed_rate: "fixed_rate",
    commission: "commission"
  }, prefix: :billing, validate: true

  validates :name, presence: true
  validates :commission_rate,
            presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 1 },
            if: :billing_commission?
  # Fixed-rate agencies carry no commission rate (mirrors the DB constraint).
  validates :commission_rate, absence: true, if: :billing_fixed_rate?

  scope :active, -> { where(active: true) }
end
