# Company settings. Only org admins may view the editable settings surface and
# update the organization record. (Everyone gets the org's public fields nested
# in /me, but editing is admin-only.)
class OrganizationPolicy < ApplicationPolicy
  def show?
    !user.agency? && user.org_admin?
  end

  def update?
    !user.agency? && user.org_admin?
  end
end
