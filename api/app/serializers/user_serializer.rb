# Canonical JSON shape for the signed-in user (drives GET /me and the Next
# session context). Role is included so the frontend can gate nav/layouts as
# defense-in-depth on top of Pundit — it is read here from the record, never
# from client input (spec §13).
module UserSerializer
  module_function

  def call(user)
    return nil unless user

    {
      type: "staff",
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      license_number: user.license_number,
      active: user.active,
      pending_invitation: user.pending_invitation?,
      office: office_payload(user.office),
      organization: OrganizationSerializer.call(user.organization)
    }
  end

  def office_payload(office)
    return nil unless office

    { id: office.id, name: office.name, city: office.city }
  end
end
