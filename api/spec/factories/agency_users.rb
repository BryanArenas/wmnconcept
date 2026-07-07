FactoryBot.define do
  factory :agency_user do
    agency
    # An agency user always belongs to the same tenant as its agency.
    organization { agency.organization }
    sequence(:email) { |n| "partner#{n}@agency.example" }
    name { "Pat Partner" }
    active { true }

    trait :with_google_identity do
      omniauth_provider { "google_oauth2" }
      sequence(:omniauth_uid) { |n| "agency-google-uid-#{n}" }
    end

    trait :inactive do
      active { false }
    end
  end
end
