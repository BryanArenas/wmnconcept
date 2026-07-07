# The physical structure under inspection (spec §3). Deduped per tenant by a
# normalized address so repeat requests against the same house reuse one row.
class Property < ApplicationRecord
  STRUCTURE_TYPES = %w[single_family condo hoa_master commercial mobile].freeze

  belongs_to :organization
  has_many :inspection_requests, dependent: :restrict_with_exception
  has_many :inspections, dependent: :restrict_with_exception

  enum :structure_type, STRUCTURE_TYPES.index_with(&:itself), validate: { allow_nil: true }

  validates :address, presence: true
  validates :state, length: { is: 2 }, allow_blank: true
  validates :normalized_address, presence: true,
                                 uniqueness: { scope: :organization_id, case_sensitive: false }

  before_validation :set_normalized_address

  # Dedup entry point used by request intake (spec §8.2 "server dedupes/creates
  # property"). Returns the existing row for a matching normalized address, or
  # creates one. The unique index is the backstop against a race.
  def self.find_or_create_for!(organization:, address:, city: nil, state: "FL", zip: nil, **attrs)
    key = normalize_key(address:, city:, state:, zip:)
    existing = find_by(organization_id: organization.id, normalized_address: key)
    return existing if existing

    create!(organization:, address:, city:, state:, zip:, **attrs)
  rescue ActiveRecord::RecordNotUnique
    find_by!(organization_id: organization.id, normalized_address: key)
  end

  # Folds street + city/state/zip into one collapsed, punctuation-free key so the
  # same street in two cities stays distinct while "123 Main St." and
  # "123 main street" collapse together.
  def self.normalize_key(address:, city: nil, state: nil, zip: nil)
    [address, city, state, zip].compact.join(" ").downcase.gsub(/[^a-z0-9]+/, " ").strip.squeeze(" ")
  end

  private

  def set_normalized_address
    self.normalized_address = self.class.normalize_key(address:, city:, state:, zip:)
  end
end
