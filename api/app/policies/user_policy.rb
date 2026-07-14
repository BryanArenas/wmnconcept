# Staff roster + provisioning. Listing is open to office staff (for the dispatch
# dropdown). Provisioning new staff is limited to org_admin and coordinators;
# the controller further restricts which *roles* a coordinator may hand out so
# they cannot escalate privilege (see UsersController::COORDINATOR_ROLES).
class UserPolicy < ApplicationPolicy
  def index? = user.org_admin? || user.coordinator? || user.manager?

  def create? = user.org_admin? || user.coordinator?

  class Scope < ApplicationPolicy::Scope
    def resolve
      super  # organization_id floor — agency users never reach this policy
    end
  end
end
