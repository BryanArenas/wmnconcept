FactoryBot.define do
  factory :availability_block do
    organization
    user { association(:user, :inspector, organization:) }
    starts_at { 2.days.from_now.change(hour: 9) }
    ends_at { 2.days.from_now.change(hour: 17) }
    all_day { false }
    reason { "Personal day" }

    trait :all_day do
      all_day { true }
      starts_at { 3.days.from_now.beginning_of_day }
      ends_at { 3.days.from_now.end_of_day }
    end
  end
end
