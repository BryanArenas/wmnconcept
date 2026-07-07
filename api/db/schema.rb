# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_07_064520) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "agencies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "billing_mode", default: "fixed_rate", null: false
    t.decimal "commission_rate", precision: 5, scale: 4
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.string "phone"
    t.string "primary_contact_email"
    t.string "type", default: "insurance", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "active"], name: "index_agencies_on_organization_id_and_active"
    t.index ["organization_id"], name: "index_agencies_on_organization_id"
    t.check_constraint "billing_mode::text = 'commission'::text AND commission_rate IS NOT NULL OR billing_mode::text = 'fixed_rate'::text AND commission_rate IS NULL", name: "agencies_commission_rate_presence_check"
    t.check_constraint "billing_mode::text = ANY (ARRAY['fixed_rate'::character varying, 'commission'::character varying]::text[])", name: "agencies_billing_mode_check"
    t.check_constraint "type::text = ANY (ARRAY['insurance'::character varying, 'real_estate'::character varying, 'other'::character varying]::text[])", name: "agencies_type_check"
  end

  create_table "agency_users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.uuid "agency_id", null: false
    t.datetime "created_at", null: false
    t.citext "email", null: false
    t.string "name", null: false
    t.string "omniauth_provider"
    t.string "omniauth_uid"
    t.uuid "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_agency_users_on_agency_id"
    t.index ["omniauth_provider", "omniauth_uid"], name: "index_agency_users_on_omniauth_identity", unique: true, where: "(omniauth_uid IS NOT NULL)"
    t.index ["organization_id", "email"], name: "index_agency_users_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_agency_users_on_organization_id"
  end

  create_table "offices", force: :cascade do |t|
    t.string "address"
    t.string "city"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.string "phone"
    t.string "state", limit: 2
    t.datetime "updated_at", null: false
    t.string "zip"
    t.index ["organization_id"], name: "index_offices_on_organization_id"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "brand_primary_hex", default: "#E11D2A", null: false
    t.datetime "created_at", null: false
    t.string "logo_url"
    t.string "name", null: false
    t.string "phone"
    t.string "primary_email"
    t.string "subdomain", null: false
    t.string "timezone", default: "America/New_York", null: false
    t.datetime "updated_at", null: false
    t.index ["subdomain"], name: "index_organizations_on_subdomain", unique: true
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.citext "email", null: false
    t.string "license_number"
    t.string "name", null: false
    t.bigint "office_id"
    t.string "omniauth_provider"
    t.string "omniauth_uid"
    t.uuid "organization_id", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["office_id"], name: "index_users_on_office_id"
    t.index ["omniauth_provider", "omniauth_uid"], name: "index_users_on_omniauth_identity", unique: true, where: "(omniauth_uid IS NOT NULL)"
    t.index ["organization_id", "email"], name: "index_users_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.check_constraint "role::text = ANY (ARRAY['org_admin'::character varying, 'coordinator'::character varying, 'inspector'::character varying, 'manager'::character varying]::text[])", name: "users_role_check"
  end

  add_foreign_key "agencies", "organizations"
  add_foreign_key "agency_users", "agencies"
  add_foreign_key "agency_users", "organizations"
  add_foreign_key "offices", "organizations"
  add_foreign_key "users", "offices"
  add_foreign_key "users", "organizations"
end
