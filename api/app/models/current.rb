# Request-scoped identity + tenant. Set once per request in the controller from
# the session; read by controllers/policies. Tenancy is enforced by explicit
# scoping (query objects / Pundit scopes), NOT a bare default_scope (spec §0).
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :organization, :request_id, :user_agent, :ip_address

  def user=(user)
    super
    self.organization = user&.organization
  end
end
