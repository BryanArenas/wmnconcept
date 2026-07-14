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

  # Review → delivery (M6, spec §8.13). Manager quality-gates; org_admin inherits
  # manager rights (spec §2). Approve fires the report pipeline; reject sends back.
  def approve? = manager_actor?
  def reject?  = manager_actor?

  # The delivered report is visible to anyone who can see the inspection — the
  # tenancy scope (agency→own, inspector→own, staff→all) already gates this.
  def report?   = true
  def download? = true

  # Read captured evidence (form answers + photos) for the review pane. Open to
  # staff reviewers (org_admin, coordinator, manager) and the field actor — but
  # never to agency principals, who only ever see the delivered report. This is
  # separate from show_form? (field capture) so a plain manager can review.
  def evidence? = staff_reviewer? || field_actor?

  private

  def staff_reviewer?
    return false if user.agency?

    user.org_admin? || user.coordinator? || user.manager?
  end

  def field_actor?
    return false if user.agency?

    user.org_admin? || user.coordinator? ||
      (user.inspector? && record.assigned_inspector_id == user.id)
  end

  def manager_actor?
    return false if user.agency?

    user.org_admin? || user.manager?
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
