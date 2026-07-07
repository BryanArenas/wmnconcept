FactoryBot.define do
  factory :payment do
    organization
    invoice { association(:invoice, organization:) }
    amount_cents { 17_500 }
    # `method` shadows Object#method in the FactoryBot DSL — set it explicitly.
    add_attribute(:method) { "card" }
    stripe_payment_intent_id { "pi_#{SecureRandom.hex(8)}" }
    paid_at { Time.current }
  end
end
