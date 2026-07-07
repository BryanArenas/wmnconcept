FactoryBot.define do
  factory :property do
    organization
    sequence(:address) { |n| "#{100 + n} Hendry St" }
    city { "Fort Myers" }
    state { "FL" }
    zip { "33901" }
    county { "Lee" }
    structure_type { "single_family" }

    trait :condo do
      structure_type { "condo" }
    end
  end
end
