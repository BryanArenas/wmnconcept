# End client (spec §3). No login at MVP — a homeowner is a contact record the
# report is delivered to. Deduped per tenant by email when one is given.
class Homeowner < ApplicationRecord
  belongs_to :organization
  has_many :inspection_requests, dependent: :restrict_with_exception
  has_many :inspections, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  # Dedup entry point used by request intake. Two clients with no email are
  # always distinct; a shared email collapses to one contact.
  def self.find_or_create_for!(organization:, name:, email: nil, phone: nil)
    normalized = email.presence&.strip&.downcase
    if normalized
      existing = find_by(organization_id: organization.id, email: normalized)
      return existing if existing
    end

    create!(organization:, name:, email: normalized, phone:)
  end
end
