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

puts "Seeded organization=#{organization.name} offices=#{organization.offices.count} users=#{organization.users.count}"
