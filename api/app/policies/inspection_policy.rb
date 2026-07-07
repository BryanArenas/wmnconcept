# Read access is broad; the scope is the tenancy gate.
# Agency users → own agency's inspections.
# Inspectors → only their own assignments (until M4 dispatch exposes the pool).
# Coordinators / org_admins → entire org.
class InspectionPolicy < ApplicationPolicy
  def index? = true
  def show?  = true

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = super  # organization_id floor
      return base.where(agency_id: user.agency_id)           if user.agency?
      return base.where(assigned_inspector_id: user.id)      if user.inspector?

      base  # coordinator / org_admin / manager see all
    end
  end
end
