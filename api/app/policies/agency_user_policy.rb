# Inviting partner logins is a staff provisioning action (spec §4:
# POST /agencies/:id/agency_users). Open to org_admin and coordinators, matching
# AgencyPolicy.
class AgencyUserPolicy < ApplicationPolicy
  def create?
    !user.agency? && (user.org_admin? || user.coordinator?)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = super # organization_id tenancy floor
      return base.where(agency_id: user.agency_id) if user.agency?

      base
    end
  end
end
