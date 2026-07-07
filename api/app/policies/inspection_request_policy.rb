# Inspection requests flow: agency submits → coordinator acts (spec §8.7).
# Scope narrows agency principals to their own agency; staff see their whole org.
class InspectionRequestPolicy < ApplicationPolicy
  # Only agency partners submit intake requests.
  def create? = user.agency?

  # Any authenticated principal may list; scope does the narrowing.
  def index? = true
  def show?  = true

  # Only coordinators and org_admins act on requests.
  def accept?  = user.org_admin? || user.coordinator?
  def decline? = user.org_admin? || user.coordinator?

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = super  # organization_id floor
      return base.where(agency_id: user.agency_id) if user.agency?

      base
    end
  end
end
