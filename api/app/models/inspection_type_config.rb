# Per-type pricing + display config (spec §11). This is where inspection prices
# LIVE — as data, not baked into a migration or into logic — so the PLACEHOLDER
# values swap on receipt of the price sheet without a code change. Only
# wind_mitigation ($175) is confirmed. Accepting a request snapshots the current
# price_cents onto each spawned inspection (spec §8.7).
class InspectionTypeConfig < ApplicationRecord
  INSPECTION_TYPES = %w[
    wind_mitigation four_point roof_condition general_home
    wind_four_combo hoa_master_wind commercial_wind
  ].freeze

  belongs_to :organization

  enum :inspection_type, INSPECTION_TYPES.index_with(&:itself), validate: true

  validates :label, presence: true
  validates :price_cents, presence: true,
                          numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :inspection_type, uniqueness: { scope: :organization_id }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :inspection_type) }

  # Convenience for the request form's "{label} · ${price}" chips (spec §8.2).
  def price_dollars = price_cents / 100.0
end
