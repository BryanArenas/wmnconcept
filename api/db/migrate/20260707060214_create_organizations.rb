class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    # Tenant root. UUID PK — reachable by URL/API (spec §0, §3). One row at launch.
    create_table :organizations, id: :uuid do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.string :primary_email
      t.string :phone
      t.string :timezone, null: false, default: "America/New_York"
      t.string :logo_url
      t.string :brand_primary_hex, null: false, default: "#E11D2A"

      t.timestamps
    end

    add_index :organizations, :subdomain, unique: true
  end
end
