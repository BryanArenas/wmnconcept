FactoryBot.define do
  factory :report do
    organization
    inspection { association(:inspection, :approved, organization:) }
    s3_key { "reports/#{SecureRandom.uuid}/wmn-report.pdf" }
    generated_at { Time.current }
    delivered_to { [] }

    trait :delivered do
      delivered_at { Time.current }
      delivered_to do
        [{ "email" => "owner@example.com", "role" => "homeowner",
           "status" => "delivered", "delivered_at" => Time.current.iso8601 }]
      end
    end
  end
end
