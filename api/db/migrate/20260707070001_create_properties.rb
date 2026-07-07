class CreateProperties < ActiveRecord::Migration[8.1]
  STRUCTURE_TYPES = %w[single_family condo hoa_master commercial mobile].freeze

  def change
    # The physical structure being inspected (spec §3). UUID PK — reachable by
    # URL/API. Deduped per org by a normalized address so re-requests against the
    # same house reuse the row (unique index below).
    create_table :properties, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: true

      t.string :address, null: false
      # Case/whitespace-normalized address used only for the dedup key. The model
      # computes it; users never see or edit it.
      t.string :normalized_address, null: false
      t.string :city
      t.string :state, limit: 2, default: "FL"
      t.string :zip
      t.string :county
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lng, precision: 10, scale: 6
      t.integer :year_built
      t.string :structure_type

      t.timestamps
    end

    # One property per normalized address per tenant (spec §3 dedup rule).
    add_index :properties, [:organization_id, :normalized_address], unique: true

    add_check_constraint :properties,
                         "structure_type IS NULL OR structure_type IN " \
                         "(#{STRUCTURE_TYPES.map { |s| "'#{s}'" }.join(', ')})",
                         name: "properties_structure_type_check"
  end
end
