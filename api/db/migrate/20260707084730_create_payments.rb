class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    # UUID PK — payments are reachable by URL/API (spec §0, §3).
    create_table :payments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :invoice_id, null: false
      t.integer :amount_cents, null: false
      t.string :method, null: false, default: "card"
      t.string :stripe_payment_intent_id
      t.datetime :paid_at

      t.timestamps
    end

    add_index :payments, :organization_id
    add_index :payments, :invoice_id
    # Idempotency backstop: a redelivered Stripe event carrying the same payment
    # intent can't create a second Payment row (spec §9 never double-bill).
    add_index :payments, :stripe_payment_intent_id, unique: true,
              where: "stripe_payment_intent_id IS NOT NULL"

    add_check_constraint :payments,
                         "method IN ('card','cash','ach')",
                         name: "payments_method_check"
    add_check_constraint :payments, "amount_cents >= 0",
                         name: "payments_amount_cents_nonneg_check"
  end
end
