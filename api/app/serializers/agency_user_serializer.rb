# Canonical JSON shape for a signed-in agency user. `type: "agency"` is the
# surface discriminator the frontend routes on (agency portal vs staff/field).
module AgencyUserSerializer
  module_function

  def call(agency_user)
    return nil unless agency_user

    {
      type: "agency",
      id: agency_user.id,
      name: agency_user.name,
      email: agency_user.email,
      active: agency_user.active,
      agency: AgencySerializer.call(agency_user.agency),
      organization: OrganizationSerializer.call(agency_user.organization)
    }
  end
end
