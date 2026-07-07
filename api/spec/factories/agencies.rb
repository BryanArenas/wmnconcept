FactoryBot.define do
  factory :agency do
    organization
    name { "Gulf Coast Insurance" }
    type { "insurance" }
    billing_mode { "fixed_rate" }
    # commission_rate stays nil for fixed_rate (DB + model constraint).
    primary_contact_email { "contact@gulfcoast.example" }
    phone { "239-555-0200" }
    active { true }

    trait :commission do
      billing_mode { "commission" }
      commission_rate { 0.15 }
    end

    trait :real_estate do
      type { "real_estate" }
      name { "Bayfront Realty" }
    end

    trait :inactive do
      active { false }
    end
  end
end
