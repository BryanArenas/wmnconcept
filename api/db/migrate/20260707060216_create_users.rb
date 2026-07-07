class CreateUsers < ActiveRecord::Migration[8.1]
  ROLES = %w[org_admin coordinator inspector manager].freeze

  def change
    # Staff + inspectors. UUID PK — reachable by URL/API (spec §3).
    create_table :users, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: true
      t.references :office, null: true, foreign_key: true, index: true # bigint FK (offices)

      t.citext :email, null: false
      t.string :name, null: false
      t.string :role, null: false
      t.string :license_number
      t.boolean :active, null: false, default: true

      # OmniAuth identity (Google + GitHub). No passwords at MVP.
      t.string :omniauth_provider
      t.string :omniauth_uid

      t.timestamps
    end

    # Email is unique per organization (spec §3: "email citext, uniq/org").
    add_index :users, [:organization_id, :email], unique: true

    # A given OAuth identity maps to exactly one user (only enforced once linked).
    add_index :users, [:omniauth_provider, :omniauth_uid],
              unique: true,
              where: "omniauth_uid IS NOT NULL",
              name: "index_users_on_omniauth_identity"

    # Role is a closed set; keep integrity at the DB, not just the model.
    add_check_constraint :users,
                         "role IN (#{ROLES.map { |r| "'#{r}'" }.join(', ')})",
                         name: "users_role_check"
  end
end
