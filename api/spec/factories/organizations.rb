FactoryBot.define do
  factory :organization do
    name { "Wind Mitigation Network" }
    sequence(:subdomain) { |n| "wmn#{n}" }
    primary_email { "office@windmitigation.network" }
    phone { "239-555-0100" }
    timezone { "America/New_York" }
    brand_primary_hex { "#E11D2A" }
  end
end
