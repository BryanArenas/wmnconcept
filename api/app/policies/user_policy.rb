# Read-only staff roster. Used by the dispatch screen to populate the inspector
# dropdown. Only office staff (coordinator, org_admin, manager) may list users.
class UserPolicy < ApplicationPolicy
  def index? = user.org_admin? || user.coordinator? || user.manager?

  class Scope < ApplicationPolicy::Scope
    def resolve
      super  # organization_id floor — agency users never reach this policy
    end
  end
end
