# Headless policy for the staff dashboard summary. Office staff (org_admin,
# coordinator, manager) get the org-wide operational snapshot; agency principals
# and inspectors have their own surfaces and never reach it.
class DashboardPolicy < Struct.new(:user, :dashboard)
  def show?
    return false if user.agency?

    user.org_admin? || user.coordinator? || user.manager?
  end
end
