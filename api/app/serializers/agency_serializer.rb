# Canonical JSON shape for an agency. commission_rate is only meaningful for
# commission-billing agencies (null otherwise, mirroring the DB constraint).
module AgencySerializer
  module_function

  def call(agency)
    return nil unless agency

    {
      id: agency.id,
      name: agency.name,
      type: agency.type,
      billing_mode: agency.billing_mode,
      commission_rate: agency.commission_rate&.to_s("F"),
      primary_contact_email: agency.primary_contact_email,
      phone: agency.phone,
      active: agency.active
    }
  end
end
