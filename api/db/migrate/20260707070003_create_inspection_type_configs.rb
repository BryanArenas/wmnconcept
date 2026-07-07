class CreateInspectionTypeConfigs < ActiveRecord::Migration[8.1]
  INSPECTION_TYPES = %w[
    wind_mitigation four_point roof_condition general_home
    hoa_master_wind wind_type_ii wind_type_iii
  ].freeze

  def change
    # Per-type pricing + display config (spec §11). Prices are PLACEHOLDERs and
    # live HERE as data, never baked into a migration default or into logic, so
    # they swap on receipt of the price sheet without a code change. Only
    # wind_mitigation = $175 is confirmed. Internal lookup table — bigint PK.
    create_table :inspection_type_configs do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: true

      t.string :inspection_type, null: false
      t.string :label, null: false
      t.integer :price_cents, null: false
      t.boolean :active, null: false, default: true
      # Order the multi-select chips render in (spec §8.2).
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    # One config row per type per tenant.
    add_index :inspection_type_configs, [:organization_id, :inspection_type], unique: true

    add_check_constraint :inspection_type_configs,
                         "inspection_type IN " \
                         "(#{INSPECTION_TYPES.map { |t| "'#{t}'" }.join(', ')})",
                         name: "inspection_type_configs_type_check"
    add_check_constraint :inspection_type_configs,
                         "price_cents >= 0",
                         name: "inspection_type_configs_price_nonneg_check"
  end
end
