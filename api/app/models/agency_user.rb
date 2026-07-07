# Partner login (spec §2, §3). Deliberately separate from staff `users` so
# partner auth and staff auth never share a surface. An agency user only ever
# sees their own agency's inspections/reports/invoices — enforced by Pundit
# scopes, never a bare default_scope.
class AgencyUser < ApplicationRecord
  belongs_to :organization
  belongs_to :agency

  validates :email, presence: true,
                    uniqueness: { scope: :organization_id, case_sensitive: false }
  validates :name, presence: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  scope :active, -> { where(active: true) }

  # Principal interface (mirrors User) so policies can treat either actor
  # uniformly. An agency user is never staff and holds no staff role.
  def staff?      = false
  def agency?     = true
  def org_admin?  = false
  def coordinator? = false
  def manager?    = false
  def inspector?  = false

  # Find or provision the agency user behind an OmniAuth callback. Partners must
  # be pre-invited; we link the identity to an existing, matching email.
  def self.from_omniauth(auth, organization:)
    provider = auth.provider.to_s
    uid = auth.uid.to_s
    email = auth.info.email.to_s.downcase

    user = find_by(omniauth_provider: provider, omniauth_uid: uid)
    user ||= active.find_by(organization_id: organization.id, email: email)
    return nil unless user&.active?

    user.update!(omniauth_provider: provider, omniauth_uid: uid) if user.omniauth_uid.blank?
    user
  end
end
