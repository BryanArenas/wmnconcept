FactoryBot.define do
  factory :user do
    organization
    sequence(:email) { |n| "staff#{n}@windmitigation.network" }
    name { "Casey Coordinator" }
    role { "coordinator" }
    active { true }

    trait :org_admin do
      role { "org_admin" }
      name { "Avery Admin" }
    end

    trait :coordinator do
      role { "coordinator" }
    end

    trait :manager do
      role { "manager" }
      name { "Morgan Manager" }
    end

    trait :inspector do
      role { "inspector" }
      name { "Ivan Inspector" }
      license_number { "HI-#{rand(10_000..99_999)}" }
      # Office belongs to the SAME tenant as the inspector.
      office { association(:office, organization: organization) }
    end

    trait :inactive do
      active { false }
    end

    # A user who has already linked a Google identity.
    trait :with_google_identity do
      omniauth_provider { "google_oauth2" }
      sequence(:omniauth_uid) { |n| "google-uid-#{n}" }
    end
  end
end
