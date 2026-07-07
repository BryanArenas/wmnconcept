# Stores the inspector's answers for the field form (one row per inspection).
# `responses` is a free-form jsonb hash keyed by the template field keys.
# ready_for_review? checks that every required key has a non-blank value here.
class InspectionFormResponse < ApplicationRecord
  belongs_to :organization
  belongs_to :inspection

  validates :responses, presence: true

  # Returns the subset of required keys that have blank/missing values.
  def missing_required_keys(template)
    template.required_field_keys.reject do |key|
      responses[key].present?
    end
  end

  def complete?(template)
    missing_required_keys(template).empty?
  end
end
