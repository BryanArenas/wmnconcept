# Request-scoped principal + tenant. The principal is either a staff User or an
# AgencyUser (separate surfaces, spec §2). Set once per request from the session;
# read by controllers/policies. Tenancy is enforced by explicit Pundit scoping,
# NOT a bare default_scope (spec §0).
class Current < ActiveSupport::CurrentAttributes
  attribute :principal, :organization, :request_id, :user_agent, :ip_address

  def principal=(principal)
    super
    self.organization = principal&.organization
  end
end
