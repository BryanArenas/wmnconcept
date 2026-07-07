FactoryBot.define do
  factory :office do
    organization
    name { "Fort Myers HQ" }
    address { "1601 Hendry St" }
    city { "Fort Myers" }
    state { "FL" }
    zip { "33901" }
    phone { "239-555-0101" }
  end
end
