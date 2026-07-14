# Staff + inspectors (spec §2). Distinct from agency_users by design so partner
# auth and staff auth never share a surface. Role comes from this record /
# the session — never a client-side switcher (spec §13).
class User < ApplicationRecord
  include Invitable

  belongs_to :organization
  belongs_to :office, optional: true

  has_many :availability_blocks, dependent: :destroy

  # Backed by a string column + DB check constraint (see migration).
  enum :role, {
    org_admin: "org_admin",
    coordinator: "coordinator",
    inspector: "inspector",
    manager: "manager"
  }, validate: true

  validates :email, presence: true,
                    uniqueness: { scope: :organization_id, case_sensitive: false }
  validates :name, presence: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  scope :active, -> { where(active: true) }

  # Principal interface (mirrors AgencyUser) so Pundit policies treat either
  # actor uniformly. A staff user is never an agency principal.
  def agency? = false

  # Org-wide-visibility staff: the staff portal (spec §2). Inspectors are the
  # field surface and are scoped to their own assignments, not org-wide.
  def office_staff?
    org_admin? || coordinator? || manager?
  end

  # Find or provision the user behind an OmniAuth callback. Staff must be
  # pre-provisioned (invited) — we link the identity to an existing, matching
  # email rather than creating arbitrary logins.
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
