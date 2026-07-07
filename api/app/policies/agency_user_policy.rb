# Inviting partner logins is an org_admin action (spec §4:
# POST /agencies/:id/agency_users, role:org_admin).
class AgencyUserPolicy < ApplicationPolicy
  def create?
    user.org_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = super # organization_id tenancy floor
      return base.where(agency_id: user.agency_id) if user.agency?

      base
    end
  end
end
