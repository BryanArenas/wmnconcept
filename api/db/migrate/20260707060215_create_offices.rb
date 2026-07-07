class CreateOffices < ActiveRecord::Migration[8.1]
  def change
    # Internal table — bigint PK (spec §3). Tenant-scoped via organization_id.
    create_table :offices do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: true
      t.string :name, null: false
      t.string :address
      t.string :city
      t.string :state, limit: 2
      t.string :zip
      t.string :phone

      t.timestamps
    end
  end
end
