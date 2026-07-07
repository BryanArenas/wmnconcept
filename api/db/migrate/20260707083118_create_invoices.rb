class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    # UUID PK — invoices are reachable by URL/API (spec §0, §4, §8.5).
    create_table :invoices, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :agency_id, null: false
      t.uuid :inspection_id, null: false
      t.integer :amount_cents, null: false
      t.string :billing_mode, null: false
      # draft → sent → paid | void (spec §3).
      t.string :status, null: false, default: "draft"
      t.string :stripe_invoice_id
      t.datetime :due_at

      t.timestamps
    end

    add_index :invoices, :organization_id
    add_index :invoices, [:organization_id, :status]
    add_index :invoices, :agency_id
    # One invoice per inspection — the idempotency backstop for CreateInvoiceJob
    # (spec §9: "idempotent on inspection_id; never double-bill").
    add_index :invoices, :inspection_id, unique: true
    add_index :invoices, :stripe_invoice_id, unique: true, where: "stripe_invoice_id IS NOT NULL"

    add_check_constraint :invoices,
                         "status IN ('draft','sent','paid','void')",
                         name: "invoices_status_check"
    add_check_constraint :invoices,
                         "billing_mode IN ('fixed_rate','commission')",
                         name: "invoices_billing_mode_check"
    add_check_constraint :invoices, "amount_cents >= 0",
                         name: "invoices_amount_cents_nonneg_check"
  end
end
