FactoryBot.define do
  factory :inspection_type_config do
    organization
    inspection_type { "wind_mitigation" }
    label { "Wind Mitigation" }
    # PLACEHOLDER price — only wind_mitigation ($175) is confirmed (spec §11).
    price_cents { 17_500 }
    active { true }
    sequence(:position)

    trait :four_point do
      inspection_type { "four_point" }
      label { "4-Point" }
      price_cents { 12_500 }
    end

    trait :inactive do
      active { false }
    end
  end
end
