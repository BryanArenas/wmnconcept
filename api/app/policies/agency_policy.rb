# Agencies are staff-managed. Per §8.9 MVP decision, management is org_admin
# only. The scope still narrows an agency principal to its own agency so the
# tenancy pattern is correct everywhere it's reused.
class AgencyPolicy < ApplicationPolicy
  def index?
    user.org_admin?
  end

  def show?
    user.org_admin? || owns_record?
  end

  def create?
    user.org_admin?
  end

  def update?
    user.org_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = super # organization_id tenancy floor
      return base.where(id: user.agency_id) if user.agency?

      base
    end
  end

  private

  def owns_record?
    user.agency? && user.agency_id == record.id
  end
end
