# Inspectors manage their own availability blocks. Scope restricts every read to
# the caller's own rows, and the mutating actions require an inspector acting on
# a record they own.
class AvailabilityBlockPolicy < ApplicationPolicy
  def index? = staff_non_agency?

  def create? = user.inspector?

  def destroy? = user.inspector? && record.user_id == user.id

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.agency?

      super.where(user_id: user.id)  # org floor + own rows only
    end
  end

  private

  def staff_non_agency?
    !user.agency?
  end
end
