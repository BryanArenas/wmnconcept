FactoryBot.define do
  factory :webhook_event do
    provider { "stripe" }
    sequence(:external_id) { |n| "evt_#{n}_#{SecureRandom.hex(4)}" }
    payload do
      {
        "id" => external_id,
        "type" => "payment_intent.succeeded",
        "data" => { "object" => { "id" => "pi_#{SecureRandom.hex(8)}" } }
      }
    end

    trait :processed do
      processed_at { Time.current }
    end
  end
end
