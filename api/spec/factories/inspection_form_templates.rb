FactoryBot.define do
  factory :inspection_form_template do
    organization
    inspection_type { "wind_mitigation" }
    active { true }
    position { 0 }
    schema do
      {
        "fields" => [
          { "key" => "roof_cover_type", "label" => "Roof cover type", "type" => "select",
            "required" => true,
            "options" => %w[shingle tile metal flat] },
          { "key" => "roof_deck_attachment", "label" => "Roof deck attachment", "type" => "select",
            "required" => true,
            "options" => %w[A B C D] },
          { "key" => "notes", "label" => "Additional notes", "type" => "text",
            "required" => false }
        ]
      }
    end

    # Minimal template with no required fields (useful for photo-only specs).
    trait :no_required_fields do
      schema do
        {
          "fields" => [
            { "key" => "notes", "label" => "Notes", "type" => "text", "required" => false }
          ]
        }
      end
    end

    # Template with a single required text field.
    trait :one_required_field do
      schema do
        {
          "fields" => [
            { "key" => "roof_cover_type", "label" => "Roof cover type", "type" => "text",
              "required" => true }
          ]
        }
      end
    end
  end
end
