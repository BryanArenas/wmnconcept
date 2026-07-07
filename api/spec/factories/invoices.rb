FactoryBot.define do
  factory :invoice do
    organization
    inspection { association(:inspection, :delivered, organization:) }
    agency { inspection.agency }
    amount_cents { 17_500 }
    billing_mode { "fixed_rate" }
    status { "draft" }
    due_at { 14.days.from_now }

    trait :sent do
      status { "sent" }
    end

    trait :paid do
      status { "paid" }
    end

    trait :commission do
      billing_mode { "commission" }
    end
  end
end
