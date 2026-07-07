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

# Inspection prices (spec §11) live HERE as data, never baked into code, so they
# swap on receipt of the price sheet. These are PLACEHOLDERs — only
# wind_mitigation ($175) is confirmed. Prices are in cents.
inspection_type_configs = [
  { inspection_type: "wind_mitigation", label: "Wind Mitigation", price_cents: 17_500 },
  { inspection_type: "four_point",      label: "4-Point",          price_cents: 12_500 },
  { inspection_type: "roof_condition",  label: "Roof Condition",   price_cents: 15_000 },
  { inspection_type: "general_home",    label: "General Home",     price_cents: 35_000 },
  { inspection_type: "hoa_master_wind", label: "HOA Master Wind",  price_cents: 45_000 },
  { inspection_type: "wind_type_ii",    label: "Wind Type II",     price_cents: 22_500 },
  { inspection_type: "wind_type_iii",   label: "Wind Type III",    price_cents: 27_500 }
]

inspection_type_configs.each_with_index do |attrs, i|
  organization.inspection_type_configs.find_or_create_by!(inspection_type: attrs[:inspection_type]) do |c|
    c.label = attrs[:label]
    c.price_cents = attrs[:price_cents]
    c.position = i
    c.active = true
  end
end

# Form templates (§11 PLACEHOLDER). Schema fields will be replaced by the
# certified OIR-B1-1802 field list when it arrives. Each type gets a minimal
# placeholder so DynamicFormRenderer has something to render in dev.
form_templates = {
  "wind_mitigation" => [
    { key: "roof_cover_type", label: "Roof cover type", type: "select", required: true,
      options: %w[shingle tile metal flat other] },
    { key: "roof_deck_attachment", label: "Roof deck attachment", type: "select", required: true,
      options: %w[A B C D] },
    { key: "roof_to_wall_connection", label: "Roof-to-wall connection", type: "select", required: true,
      options: ["Toe nails", "Clips", "Single wraps", "Double wraps", "Structural"] },
    { key: "opening_protection", label: "Opening protection", type: "select", required: true,
      options: ["None", "Basic", "Hurricane", "Impact"] },
    { key: "notes", label: "Additional notes", type: "text", required: false }
  ],
  "four_point" => [
    { key: "roof_age_years", label: "Roof age (years)", type: "number", required: true },
    { key: "hvac_age_years", label: "HVAC age (years)", type: "number", required: true },
    { key: "electrical_panel_type", label: "Electrical panel type", type: "text", required: true },
    { key: "plumbing_type", label: "Plumbing type", type: "select", required: true,
      options: %w[Copper PVC Galvanized CPVC Other] },
    { key: "notes", label: "Notes", type: "text", required: false }
  ],
  "roof_condition" => [
    { key: "roof_material", label: "Roof material", type: "select", required: true,
      options: %w[Shingle Tile Metal Flat Other] },
    { key: "roof_age_years", label: "Estimated age (years)", type: "number", required: true },
    { key: "condition_rating", label: "Condition rating", type: "select", required: true,
      options: %w[Poor Fair Good Excellent] },
    { key: "notes", label: "Notes", type: "text", required: false }
  ],
  "general_home" => [
    { key: "year_built", label: "Year built", type: "number", required: true },
    { key: "foundation_type", label: "Foundation type", type: "select", required: true,
      options: ["Slab", "Crawl space", "Basement", "Piers"] },
    { key: "notes", label: "Notes", type: "text", required: false }
  ],
  "hoa_master_wind" => [
    { key: "building_count", label: "Building count", type: "number", required: true },
    { key: "construction_type", label: "Construction type", type: "text", required: true },
    { key: "notes", label: "Notes", type: "text", required: false }
  ],
  "wind_type_ii" => [
    { key: "opening_protection", label: "Opening protection", type: "select", required: true,
      options: ["None", "Basic", "Hurricane", "Impact"] },
    { key: "notes", label: "Notes", type: "text", required: false }
  ],
  "wind_type_iii" => [
    { key: "opening_protection", label: "Opening protection", type: "select", required: true,
      options: ["None", "Basic", "Hurricane", "Impact"] },
    { key: "compliance_level", label: "Compliance level", type: "text", required: true },
    { key: "notes", label: "Notes", type: "text", required: false }
  ]
}

form_templates.each_with_index do |(itype, fields), i|
  organization.inspection_form_templates.find_or_create_by!(inspection_type: itype) do |t|
    t.schema = { "fields" => fields.map(&:stringify_keys) }
    t.active = true
    t.position = i
  end
end

puts "Seeded organization=#{organization.name} offices=#{organization.offices.count} " \
     "users=#{organization.users.count} agencies=#{organization.agencies.count} " \
     "agency_users=#{organization.agency_users.count} " \
     "inspection_type_configs=#{organization.inspection_type_configs.count} " \
     "form_templates=#{organization.inspection_form_templates.count}"
