FactoryBot.define do
  factory :homeowner do
    organization
    name { "Dana Homeowner" }
    sequence(:email) { |n| "owner#{n}@example.com" }
    phone { "239-555-0300" }

    trait :no_email do
      email { nil }
    end
  end
end
