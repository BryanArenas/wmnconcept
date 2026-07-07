# Per-type form schema (§11 PLACEHOLDER). The `schema` jsonb column drives
# DynamicFormRenderer on the field app; it swaps without code changes when the
# certified OIR-B1-1802 field list arrives.
#
# Schema shape: { "fields" => [{ "key", "label", "type", "required", "options" }] }
# Types: text | number | boolean | select | multi_select
class InspectionFormTemplate < ApplicationRecord
  INSPECTION_TYPES = InspectionTypeConfig::INSPECTION_TYPES

  belongs_to :organization

  enum :inspection_type, INSPECTION_TYPES.index_with(&:itself), validate: true

  validates :schema, presence: true
  validates :inspection_type, uniqueness: { scope: :organization_id }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :inspection_type) }

  def fields
    schema.fetch("fields", [])
  end

  def required_field_keys
    fields.select { |f| f["required"] }.map { |f| f["key"] }
  end
end
