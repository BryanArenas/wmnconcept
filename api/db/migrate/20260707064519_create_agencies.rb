class CreateAgencies < ActiveRecord::Migration[8.1]
  TYPES = %w[insurance real_estate other].freeze
  BILLING_MODES = %w[fixed_rate commission].freeze

  def change
    # Referral partners (spec §3). UUID PK — reachable by URL/API.
    create_table :agencies, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: true

      t.string :name, null: false
      # Agency kind (spec §3 calls this `type`). The Agency model disables STI
      # (self.inheritance_column = nil) so `type` is a plain enum column.
      t.string :type, null: false, default: "insurance"
      t.string :primary_contact_email
      t.string :phone

      # Commission-mode agencies bill a % of the fee; fixed-rate bill a flat fee.
      t.string :billing_mode, null: false, default: "fixed_rate"
      t.decimal :commission_rate, precision: 5, scale: 4 # e.g. 0.1500 = 15%

      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :agencies, [:organization_id, :active]

    add_check_constraint :agencies,
                         "type IN (#{TYPES.map { |t| "'#{t}'" }.join(', ')})",
                         name: "agencies_type_check"
    add_check_constraint :agencies,
                         "billing_mode IN (#{BILLING_MODES.map { |m| "'#{m}'" }.join(', ')})",
                         name: "agencies_billing_mode_check"
    # Commission billing must carry a rate; fixed-rate must not (enforced at DB).
    add_check_constraint :agencies,
                         "(billing_mode = 'commission' AND commission_rate IS NOT NULL) OR " \
                         "(billing_mode = 'fixed_rate' AND commission_rate IS NULL)",
                         name: "agencies_commission_rate_presence_check"
  end
end
