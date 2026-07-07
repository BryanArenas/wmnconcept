# Billing visibility (spec §4, §8.5). Agency users see their own agency's
# invoices; office staff (org_admin/coordinator/manager) see all and can send.
# Inspectors have no billing surface.
class InvoicePolicy < ApplicationPolicy
  def index? = agency_or_office_staff?
  def show?  = agency_or_office_staff?

  # Sending (draft → sent, creates the Stripe invoice) is staff-only (spec §4).
  def send_invoice?
    !user.agency? && user.office_staff?
  end

  private

  def agency_or_office_staff?
    user.agency? || (!user.agency? && user.office_staff?)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = super # organization_id floor
      return base.where(agency_id: user.agency_id) if user.agency?
      return base.none if user.inspector?

      base # org_admin / coordinator / manager see all
    end
  end
end
