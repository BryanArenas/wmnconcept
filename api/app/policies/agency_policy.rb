# Agencies are staff-managed. Management is open to org_admin and coordinators
# (day-to-day operations); the scope still narrows an agency principal to its
# own agency so the tenancy pattern is correct everywhere it's reused.
class AgencyPolicy < ApplicationPolicy
  def index?
    provisioner?
  end

  def show?
    provisioner? || owns_record?
  end

  def create?
    provisioner?
  end

  def update?
    provisioner?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = super # organization_id tenancy floor
      return base.where(id: user.agency_id) if user.agency?

      base
    end
  end

  private

  # Staff who may manage agencies: org admins and coordinators. Agency
  # principals answer false to both role checks, but guard explicitly so intent
  # is obvious and a future role rename can't silently open this up.
  def provisioner?
    !user.agency? && (user.org_admin? || user.coordinator?)
  end

  def owns_record?
    user.agency? && user.agency_id == record.id
  end
end
