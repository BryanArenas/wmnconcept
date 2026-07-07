class CreateHomeowners < ActiveRecord::Migration[8.1]
  def change
    # End client (spec §3). No login at MVP. UUID PK — reachable by URL/API.
    # Deduped per org by email when one is present (see Homeowner model).
    create_table :homeowners, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: true

      t.string :name, null: false
      t.citext :email
      t.string :phone

      t.timestamps
    end

    # Fast lookup for the per-org email dedup. Not unique: a homeowner may have no
    # email, and two distinct people can legitimately lack one.
    add_index :homeowners, [:organization_id, :email]
  end
end
