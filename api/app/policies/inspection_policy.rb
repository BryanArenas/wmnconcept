# Read access is broad; the scope is the tenancy gate.
# Agency users → own agency's inspections.
# Inspectors → only their own assignments.
# Coordinators / org_admins → entire org.
class InspectionPolicy < ApplicationPolicy
  def index? = true
  def show?  = true

  # Coordinator-only dispatch actions (spec §8.8).
  def assign?   = user.org_admin? || user.coordinator?
  def schedule? = user.org_admin? || user.coordinator?
  def cancel?   = user.org_admin? || user.coordinator?

  # Inspectors may start their own inspections (on-site); coordinators/org_admins
  # can also trigger start (e.g. on behalf of an inspector without the app).
  def start?
    return false if user.agency?

    user.org_admin? || user.coordinator? ||
      (user.inspector? && record.assigned_inspector_id == user.id)
  end

  # Field capture (M5): inspector on the assignment or staff with elevated access.
  def upload_photo?    = field_actor?
  def confirm_photo?   = field_actor?
  def show_form?       = field_actor?
  def save_form?       = field_actor?
  def submit?          = field_actor?

  private

  def field_actor?
    return false if user.agency?

    user.org_admin? || user.coordinator? ||
      (user.inspector? && record.assigned_inspector_id == user.id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = super  # organization_id floor
      return base.where(agency_id: user.agency_id)       if user.agency?
      return base.where(assigned_inspector_id: user.id)  if user.inspector?

      base  # coordinator / org_admin / manager see all
    end
  end
end
