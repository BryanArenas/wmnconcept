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

# Inspection prices — Florida fair-market averages (2024–2025). Prices in cents.
# wind_mitigation ($175) is confirmed; the rest are competitive SW Florida
# rates sourced from market comps. Adjust via the admin panel or re-seed.
inspection_type_configs = [
  { inspection_type: "wind_mitigation", label: "Wind Mitigation",           price_cents: 17_500 },
  { inspection_type: "four_point",      label: "4-Point Inspection",        price_cents: 15_000 },
  { inspection_type: "roof_condition",  label: "Roof Condition Letter",     price_cents: 17_500 },
  { inspection_type: "general_home",    label: "General Home Inspection",   price_cents: 35_000 },
  { inspection_type: "wind_four_combo", label: "Wind + 4-Point Combo",      price_cents: 25_000 },
  { inspection_type: "hoa_master_wind", label: "HOA / Condo Master Wind",   price_cents: 50_000 },
  { inspection_type: "commercial_wind", label: "Commercial Wind Mitigation", price_cents: 75_000 }
]

inspection_type_configs.each_with_index do |attrs, i|
  organization.inspection_type_configs.find_or_create_by!(inspection_type: attrs[:inspection_type]) do |c|
    c.label = attrs[:label]
    c.price_cents = attrs[:price_cents]
    c.position = i
    c.active = true
  end
end

# ─── Form templates ───────────────────────────────────────────────────────────
# The wind_mitigation schema mirrors the OIR-B1-1802 Uniform Mitigation
# Verification Inspection Form sections (Building Code, Roof Covering, Roof
# Deck Attachment, Roof-to-Wall, Roof Geometry, SWR, Opening Protection).
# Other types carry the standard inspection fields for their domain.
form_templates = {
  "wind_mitigation" => [
    # ── Section 1: Building Code ──
    { key: "year_built", label: "Year built", type: "number", required: true },
    { key: "building_code", label: "Building code compliance", type: "select", required: true,
      options: [
        "Pre-1994 (no FBC)",
        "1994–2001 South Florida Building Code",
        "2002+ Florida Building Code",
        "2007+ FBC — Enhanced hurricane"
      ] },
    { key: "permit_date", label: "Original permit date (if known)", type: "text", required: false },

    # ── Section 2: Roof Covering ──
    { key: "roof_cover_type", label: "Roof covering type", type: "select", required: true,
      options: [
        "Asphalt/fiberglass shingle",
        "Concrete/clay tile",
        "Metal (standing seam)",
        "Metal (corrugated/screw-down)",
        "Built-up/modified bitumen (flat)",
        "Single-ply membrane (TPO/EPDM)",
        "Wood shake/shingle",
        "Slate",
        "Other"
      ] },
    { key: "roof_cover_fbc_equivalent", label: "Roof covering FBC equivalent?", type: "select", required: true,
      options: ["Yes — FBC compliant", "No — non-compliant", "Unknown"] },
    { key: "roof_permit_date", label: "Roof permit date (if re-roofed)", type: "text", required: false },

    # ── Section 3: Roof Deck Attachment ──
    { key: "roof_deck_attachment", label: "Roof deck attachment", type: "select", required: true,
      options: [
        "A — 6d nails, 6\" spacing",
        "B — 8d nails, 6\" spacing",
        "C — 8d nails, 6\" edge / 12\" field",
        "D — 8d ring-shank nails, 6\" spacing",
        "Reinforced concrete deck",
        "Other/Unknown"
      ] },

    # ── Section 4: Roof-to-Wall Attachment ──
    { key: "roof_to_wall_connection", label: "Roof-to-wall connection", type: "select", required: true,
      options: [
        "Toe nails",
        "Clips",
        "Single wraps",
        "Double wraps",
        "Structural (bolted/epoxied)",
        "Other/Unknown"
      ] },

    # ── Section 5: Roof Geometry ──
    { key: "roof_geometry", label: "Roof shape", type: "select", required: true,
      options: [
        "Hip (100%)",
        "Flat",
        "Gable",
        "Hip + Gable combination",
        "Other"
      ] },
    { key: "hip_percent", label: "% hip (if combination)", type: "number", required: false },

    # ── Section 6: Secondary Water Resistance (SWR) ──
    { key: "swr", label: "Secondary water resistance (SWR)", type: "select", required: true,
      options: [
        "SWR — self-adhering modified bitumen",
        "SWR — foam adhesive (FBC approved)",
        "No SWR / Unknown"
      ] },

    # ── Section 7: Opening Protection ──
    { key: "opening_protection", label: "Opening protection level", type: "select", required: true,
      options: [
        "None",
        "Basic shutters (plywood/panels)",
        "Hurricane shutters (accordion/roll-down/Bahama)",
        "Impact-rated glazing (windows and doors)",
        "Impact-rated glazing + shutters (mixed)",
        "All openings — impact rated or shuttered"
      ] },
    { key: "garage_door_braced", label: "Garage door wind-rated or braced?", type: "select", required: true,
      options: ["Yes — wind-rated", "Yes — aftermarket bracing", "No", "N/A — no garage"] },
    { key: "entry_doors_rated", label: "Entry doors impact-rated?", type: "select", required: true,
      options: ["Yes", "No", "Some/Mixed"] },

    # ── General ──
    { key: "inspector_notes", label: "Inspector notes", type: "text", required: false }
  ],

  "four_point" => [
    # Roof
    { key: "roof_material", label: "Roof material", type: "select", required: true,
      options: ["Asphalt shingle", "Tile", "Metal", "Flat/built-up", "Other"] },
    { key: "roof_age_years", label: "Roof age (years)", type: "number", required: true },
    { key: "roof_condition", label: "Roof condition", type: "select", required: true,
      options: %w[Poor Fair Good Excellent] },
    { key: "roof_permit_date", label: "Roof permit date (if available)", type: "text", required: false },
    # Electrical
    { key: "electrical_panel_type", label: "Electrical panel type", type: "select", required: true,
      options: ["Circuit breakers", "Fuses", "Federal Pacific / Zinsco (defective)", "Other"] },
    { key: "electrical_amps", label: "Service amperage", type: "select", required: true,
      options: ["100 amp", "150 amp", "200 amp", "Other"] },
    { key: "wiring_type", label: "Wiring type", type: "select", required: true,
      options: ["Copper", "Aluminum", "Knob-and-tube", "Mixed", "Unknown"] },
    # Plumbing
    { key: "plumbing_supply_type", label: "Supply plumbing", type: "select", required: true,
      options: %w[Copper CPVC PEX Galvanized Polybutylene Other] },
    { key: "plumbing_drain_type", label: "Drain plumbing", type: "select", required: true,
      options: ["Cast iron", "PVC", "ABS", "Mixed", "Other"] },
    { key: "water_heater_age", label: "Water heater age (years)", type: "number", required: true },
    # HVAC
    { key: "hvac_type", label: "HVAC system type", type: "select", required: true,
      options: ["Central A/C + furnace", "Heat pump", "Mini-split/ductless", "Window units", "Other"] },
    { key: "hvac_age_years", label: "HVAC age (years)", type: "number", required: true },
    { key: "hvac_condition", label: "HVAC condition", type: "select", required: true,
      options: %w[Poor Fair Good Excellent] },
    { key: "notes", label: "Inspector notes", type: "text", required: false }
  ],

  "roof_condition" => [
    { key: "roof_material", label: "Roof material", type: "select", required: true,
      options: ["Asphalt shingle", "Concrete tile", "Clay tile", "Metal", "Flat/modified bitumen", "Other"] },
    { key: "roof_age_years", label: "Estimated roof age (years)", type: "number", required: true },
    { key: "roof_layers", label: "Number of roof layers", type: "select", required: true,
      options: %w[1 2 3+] },
    { key: "condition_rating", label: "Overall condition", type: "select", required: true,
      options: %w[Poor Fair Good Excellent] },
    { key: "remaining_life_years", label: "Estimated remaining life (years)", type: "number", required: true },
    { key: "visible_damage", label: "Visible damage?", type: "boolean", required: true },
    { key: "damage_description", label: "Damage description (if any)", type: "text", required: false },
    { key: "leak_evidence", label: "Evidence of leaks?", type: "boolean", required: true },
    { key: "notes", label: "Inspector notes", type: "text", required: false }
  ],

  "general_home" => [
    { key: "year_built", label: "Year built", type: "number", required: true },
    { key: "sqft", label: "Living area (sq ft)", type: "number", required: true },
    { key: "stories", label: "Number of stories", type: "select", required: true,
      options: ["1", "1.5", "2", "3+"] },
    { key: "foundation_type", label: "Foundation type", type: "select", required: true,
      options: ["Slab on grade", "Crawl space", "Basement", "Piers/pilings"] },
    { key: "construction_type", label: "Construction type", type: "select", required: true,
      options: ["CBS (concrete block/stucco)", "Wood frame", "Steel frame", "Manufactured/modular"] },
    { key: "roof_material", label: "Roof material", type: "select", required: true,
      options: ["Shingle", "Tile", "Metal", "Flat", "Other"] },
    { key: "roof_age_years", label: "Roof age (years)", type: "number", required: true },
    { key: "electrical_panel_type", label: "Electrical panel type", type: "select", required: true,
      options: ["Circuit breakers", "Fuses", "Federal Pacific/Zinsco", "Other"] },
    { key: "plumbing_type", label: "Supply plumbing", type: "select", required: true,
      options: %w[Copper CPVC PEX Galvanized Polybutylene Other] },
    { key: "hvac_type", label: "HVAC type", type: "select", required: true,
      options: ["Central A/C", "Heat pump", "Mini-split", "Window units", "Other"] },
    { key: "hvac_age_years", label: "HVAC age (years)", type: "number", required: true },
    { key: "notes", label: "Inspector notes", type: "text", required: false }
  ],

  "wind_four_combo" => [
    { key: "combo_note", label: "This is a combined Wind Mitigation + 4-Point report", type: "text", required: false },
    # Wind mit (abbreviated — key sections)
    { key: "year_built", label: "Year built", type: "number", required: true },
    { key: "building_code", label: "Building code compliance", type: "select", required: true,
      options: ["Pre-1994", "1994–2001 SFBC", "2002+ FBC", "2007+ FBC Enhanced"] },
    { key: "roof_cover_type", label: "Roof covering", type: "select", required: true,
      options: ["Shingle", "Tile", "Metal (standing seam)", "Metal (screw-down)", "Flat/membrane", "Other"] },
    { key: "roof_deck_attachment", label: "Roof deck attachment", type: "select", required: true,
      options: ["A", "B", "C", "D", "Reinforced concrete", "Unknown"] },
    { key: "roof_to_wall_connection", label: "Roof-to-wall connection", type: "select", required: true,
      options: ["Toe nails", "Clips", "Single wraps", "Double wraps", "Structural"] },
    { key: "roof_geometry", label: "Roof shape", type: "select", required: true,
      options: ["Hip", "Flat", "Gable", "Combination", "Other"] },
    { key: "swr", label: "Secondary water resistance", type: "select", required: true,
      options: ["Yes — SWR present", "No SWR"] },
    { key: "opening_protection", label: "Opening protection", type: "select", required: true,
      options: ["None", "Basic", "Hurricane shutters", "Impact-rated", "Mixed"] },
    # 4-Point sections
    { key: "roof_age_years", label: "Roof age (years)", type: "number", required: true },
    { key: "roof_condition", label: "Roof condition", type: "select", required: true,
      options: %w[Poor Fair Good Excellent] },
    { key: "electrical_panel_type", label: "Electrical panel", type: "select", required: true,
      options: ["Circuit breakers", "Fuses", "Federal Pacific/Zinsco", "Other"] },
    { key: "wiring_type", label: "Wiring type", type: "select", required: true,
      options: ["Copper", "Aluminum", "Knob-and-tube", "Mixed"] },
    { key: "plumbing_supply_type", label: "Supply plumbing", type: "select", required: true,
      options: %w[Copper CPVC PEX Galvanized Polybutylene Other] },
    { key: "hvac_age_years", label: "HVAC age (years)", type: "number", required: true },
    { key: "hvac_type", label: "HVAC type", type: "select", required: true,
      options: ["Central A/C", "Heat pump", "Mini-split", "Other"] },
    { key: "notes", label: "Inspector notes", type: "text", required: false }
  ],

  "hoa_master_wind" => [
    { key: "community_name", label: "Community / HOA name", type: "text", required: true },
    { key: "building_count", label: "Number of buildings", type: "number", required: true },
    { key: "units_per_building", label: "Units per building (avg)", type: "number", required: true },
    { key: "year_built", label: "Year built", type: "number", required: true },
    { key: "construction_type", label: "Construction type", type: "select", required: true,
      options: ["CBS (concrete block/stucco)", "Wood frame", "Steel frame", "Other"] },
    { key: "roof_cover_type", label: "Roof covering", type: "select", required: true,
      options: ["Shingle", "Tile", "Metal", "Flat/membrane", "Other"] },
    { key: "roof_deck_attachment", label: "Roof deck attachment", type: "select", required: true,
      options: ["A", "B", "C", "D", "Reinforced concrete", "Unknown"] },
    { key: "roof_to_wall_connection", label: "Roof-to-wall connection", type: "select", required: true,
      options: ["Toe nails", "Clips", "Single wraps", "Double wraps", "Structural"] },
    { key: "roof_geometry", label: "Roof shape", type: "select", required: true,
      options: ["Hip", "Flat", "Gable", "Combination"] },
    { key: "swr", label: "Secondary water resistance", type: "select", required: true,
      options: ["Yes — SWR present", "No SWR"] },
    { key: "opening_protection", label: "Opening protection", type: "select", required: true,
      options: ["None", "Basic shutters", "Hurricane shutters", "Impact-rated", "Mixed"] },
    { key: "notes", label: "Inspector notes", type: "text", required: false }
  ],

  "commercial_wind" => [
    { key: "business_name", label: "Business / building name", type: "text", required: true },
    { key: "year_built", label: "Year built", type: "number", required: true },
    { key: "building_sqft", label: "Building area (sq ft)", type: "number", required: true },
    { key: "construction_type", label: "Construction type", type: "select", required: true,
      options: ["CBS", "Steel frame", "Tilt-up concrete", "Wood frame", "Other"] },
    { key: "stories", label: "Number of stories", type: "select", required: true,
      options: ["1", "2", "3", "4+"] },
    { key: "roof_cover_type", label: "Roof covering", type: "select", required: true,
      options: ["Metal", "TPO/EPDM membrane", "Built-up", "Tile", "Shingle", "Other"] },
    { key: "roof_deck_attachment", label: "Roof deck attachment", type: "select", required: true,
      options: ["A", "B", "C", "D", "Reinforced concrete", "Unknown"] },
    { key: "roof_to_wall_connection", label: "Roof-to-wall connection", type: "select", required: true,
      options: ["Toe nails", "Clips", "Single wraps", "Double wraps", "Structural"] },
    { key: "roof_geometry", label: "Roof shape", type: "select", required: true,
      options: ["Hip", "Flat", "Gable", "Combination"] },
    { key: "swr", label: "Secondary water resistance", type: "select", required: true,
      options: ["Yes", "No"] },
    { key: "opening_protection", label: "Opening protection", type: "select", required: true,
      options: ["None", "Basic", "Hurricane shutters", "Impact-rated", "Mixed"] },
    { key: "notes", label: "Inspector notes", type: "text", required: false }
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
