class CreateAgencyUsers < ActiveRecord::Migration[8.1]
  def change
    # Partner logins (spec §3). Separate table from staff `users` by design so
    # partner auth and staff auth never share a surface (spec §2). UUID PK.
    create_table :agency_users, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: true
      t.references :agency, null: false, type: :uuid, foreign_key: true, index: true

      t.citext :email, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      # OmniAuth identity (Google + GitHub). No passwords at MVP.
      t.string :omniauth_provider
      t.string :omniauth_uid

      t.timestamps
    end

    # Email unique per organization (a partner contact resolves to one login).
    add_index :agency_users, [:organization_id, :email], unique: true

    # A given OAuth identity maps to exactly one agency user (once linked).
    add_index :agency_users, [:omniauth_provider, :omniauth_uid],
              unique: true,
              where: "omniauth_uid IS NOT NULL",
              name: "index_agency_users_on_omniauth_identity"
  end
end
