FactoryBot.define do
  factory :inspection_form_response do
    organization
    inspection
    responses do
      { "roof_cover_type" => "shingle", "roof_deck_attachment" => "B" }
    end

    trait :empty do
      responses { {} }
    end
  end
end
