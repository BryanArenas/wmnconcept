# Idempotent seed for the launch tenant. Safe to re-run in any environment.
# M1 scope (spec §12): 1 organization (WMN) + 2 offices + sample staff.
# Later milestones seed form templates and the PLACEHOLDER price list (§11).

organization = Organization.find_or_create_by!(subdomain: "wmn") do |org|
  org.name = "Wind Mitigation Network"
  org.primary_email = "office@windmitigation.network"
  org.phone = "239-887-3948"
  org.timezone = "America/New_York"
  org.brand_primary_hex = "#E11D2A"
end

offices = {
  fort_myers: organization.offices.find_or_create_by!(name: "Fort Myers HQ") do |o|
    o.address = "1601 Hendry St"
    o.city = "Fort Myers"
    o.state = "FL"
    o.zip = "33901"
    o.phone = "239-887-3948"
  end,
  cape_coral: organization.offices.find_or_create_by!(name: "Cape Coral") do |o|
    o.address = "1039 Del Prado Blvd S"
    o.city = "Cape Coral"
    o.state = "FL"
    o.zip = "33990"
    o.phone = "239-887-3949"
  end
}

# Sample staff — one per role — so every surface has a signed-in identity to
# demo against. OmniAuth links a real provider uid on first login.
staff = [
  { email: "admin@windmitigation.network",       name: "Avery Admin",       role: "org_admin",   office: offices[:fort_myers] },
  { email: "coordinator@windmitigation.network", name: "Casey Coordinator", role: "coordinator", office: offices[:fort_myers] },
  { email: "manager@windmitigation.network",     name: "Morgan Manager",    role: "manager",     office: offices[:fort_myers] },
  { email: "inspector@windmitigation.network",   name: "Ivan Inspector",    role: "inspector",   office: offices[:cape_coral], license_number: "HI-10482" }
]

staff.each do |attrs|
  organization.users.find_or_create_by!(email: attrs[:email]) do |u|
    u.name = attrs[:name]
    u.role = attrs[:role]
    u.office = attrs[:office]
    u.license_number = attrs[:license_number]
    u.active = true
  end
end

# Referral partners (M2) + one partner login each, so the agency portal and the
# staff Agencies screen have data to render.
agencies = [
  {
    name: "Gulf Coast Insurance", type: "insurance", billing_mode: "fixed_rate",
    primary_contact_email: "ops@gulfcoast.example", phone: "239-555-0200",
    contact: { name: "Pat Partner", email: "pat@gulfcoast.example" }
  },
  {
    name: "Bayfront Realty", type: "real_estate", billing_mode: "commission",
    commission_rate: 0.15, primary_contact_email: "deals@bayfront.example", phone: "239-555-0210",
    contact: { name: "Riley Realtor", email: "riley@bayfront.example" }
  }
]

agencies.each do |attrs|
  contact = attrs.delete(:contact)
  agency = organization.agencies.find_or_create_by!(name: attrs[:name]) do |a|
    a.type = attrs[:type]
    a.billing_mode = attrs[:billing_mode]
    a.commission_rate = attrs[:commission_rate]
    a.primary_contact_email = attrs[:primary_contact_email]
    a.phone = attrs[:phone]
  end

  agency.agency_users.find_or_create_by!(email: contact[:email]) do |u|
    u.organization = organization
    u.name = contact[:name]
  end
end

puts "Seeded organization=#{organization.name} offices=#{organization.offices.count} " \
     "users=#{organization.users.count} agencies=#{organization.agencies.count} " \
     "agency_users=#{organization.agency_users.count}"
