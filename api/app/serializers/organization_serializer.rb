# Canonical JSON shape for an organization. lib/types.ts on the Next side
# mirrors this; keep them in sync.
module OrganizationSerializer
  module_function

  def call(organization)
    return nil unless organization

    {
      id: organization.id,
      name: organization.name,
      subdomain: organization.subdomain,
      brand_primary_hex: organization.brand_primary_hex,
      logo_url: organization.logo_url,
      timezone: organization.timezone,
      phone: organization.phone,
      primary_email: organization.primary_email
    }
  end
end
