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

ActiveRecord::Schema[8.1].define(version: 2026_07_07_084730) do
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

  create_table "homeowners", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.citext "email"
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "email"], name: "index_homeowners_on_organization_id_and_email"
    t.index ["organization_id"], name: "index_homeowners_on_organization_id"
  end

  create_table "inspection_events", force: :cascade do |t|
    t.uuid "actor_id"
    t.string "actor_label"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.string "from_status"
    t.uuid "inspection_id", null: false
    t.string "kind", null: false
    t.string "message", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.uuid "organization_id", null: false
    t.string "to_status"
    t.datetime "updated_at", null: false
    t.index ["inspection_id", "occurred_at"], name: "index_inspection_events_on_inspection_id_and_occurred_at"
    t.index ["inspection_id"], name: "index_inspection_events_on_inspection_id"
    t.index ["organization_id"], name: "index_inspection_events_on_organization_id"
  end

  create_table "inspection_form_responses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "inspection_id", null: false
    t.uuid "organization_id", null: false
    t.jsonb "responses", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["inspection_id"], name: "index_inspection_form_responses_on_inspection_id", unique: true
    t.index ["organization_id"], name: "index_inspection_form_responses_on_organization_id"
  end

  create_table "inspection_form_templates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "inspection_type", null: false
    t.uuid "organization_id", null: false
    t.integer "position", default: 0, null: false
    t.jsonb "schema", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "inspection_type"], name: "index_form_templates_on_org_and_type", unique: true
    t.index ["organization_id", "position"], name: "index_form_templates_on_org_and_position"
    t.index ["organization_id"], name: "index_inspection_form_templates_on_organization_id"
  end

  create_table "inspection_photos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename"
    t.uuid "inspection_id", null: false
    t.uuid "organization_id", null: false
    t.string "s3_key", null: false
    t.datetime "updated_at", null: false
    t.string "upload_state", default: "pending", null: false
    t.index ["inspection_id", "upload_state"], name: "index_inspection_photos_on_inspection_and_state"
    t.index ["inspection_id"], name: "index_inspection_photos_on_inspection_id"
    t.index ["organization_id"], name: "index_inspection_photos_on_organization_id"
    t.index ["s3_key"], name: "index_inspection_photos_on_s3_key", unique: true
    t.check_constraint "upload_state::text = ANY (ARRAY['pending'::character varying, 'uploaded'::character varying]::text[])", name: "inspection_photos_upload_state_check"
  end

  create_table "inspection_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_id", null: false
    t.datetime "created_at", null: false
    t.text "decline_reason"
    t.uuid "homeowner_id", null: false
    t.text "notes"
    t.uuid "organization_id", null: false
    t.string "preferred_dates"
    t.uuid "property_id", null: false
    t.string "requested_types", default: [], null: false, array: true
    t.string "status", default: "submitted", null: false
    t.uuid "submitted_by_agency_user_id"
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_inspection_requests_on_agency_id"
    t.index ["homeowner_id"], name: "index_inspection_requests_on_homeowner_id"
    t.index ["organization_id", "status"], name: "index_inspection_requests_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_inspection_requests_on_organization_id"
    t.index ["property_id"], name: "index_inspection_requests_on_property_id"
    t.index ["submitted_by_agency_user_id"], name: "index_inspection_requests_on_submitted_by_agency_user_id"
    t.check_constraint "array_length(requested_types, 1) >= 1", name: "inspection_requests_types_present_check"
    t.check_constraint "requested_types <@ ARRAY['wind_mitigation'::character varying, 'four_point'::character varying, 'roof_condition'::character varying, 'general_home'::character varying, 'hoa_master_wind'::character varying, 'wind_type_ii'::character varying, 'wind_type_iii'::character varying]", name: "inspection_requests_types_valid_check"
    t.check_constraint "status::text = ANY (ARRAY['submitted'::character varying, 'accepted'::character varying, 'declined'::character varying]::text[])", name: "inspection_requests_status_check"
  end

  create_table "inspection_type_configs", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "inspection_type", null: false
    t.string "label", null: false
    t.uuid "organization_id", null: false
    t.integer "position", default: 0, null: false
    t.integer "price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "inspection_type"], name: "idx_on_organization_id_inspection_type_f0b851debb", unique: true
    t.index ["organization_id"], name: "index_inspection_type_configs_on_organization_id"
    t.check_constraint "inspection_type::text = ANY (ARRAY['wind_mitigation'::character varying, 'four_point'::character varying, 'roof_condition'::character varying, 'general_home'::character varying, 'hoa_master_wind'::character varying, 'wind_type_ii'::character varying, 'wind_type_iii'::character varying]::text[])", name: "inspection_type_configs_type_check"
    t.check_constraint "price_cents >= 0", name: "inspection_type_configs_price_nonneg_check"
  end

  create_table "inspections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_id", null: false
    t.datetime "approved_at"
    t.uuid "assigned_inspector_id"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.uuid "homeowner_id", null: false
    t.uuid "inspection_request_id", null: false
    t.string "inspection_type", null: false
    t.bigint "office_id"
    t.uuid "organization_id", null: false
    t.integer "price_cents", null: false
    t.uuid "property_id", null: false
    t.text "rejection_note"
    t.datetime "scheduled_at"
    t.datetime "started_at"
    t.string "status", default: "unassigned", null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_inspections_on_agency_id"
    t.index ["assigned_inspector_id", "scheduled_at"], name: "index_inspections_on_assigned_inspector_id_and_scheduled_at"
    t.index ["assigned_inspector_id"], name: "index_inspections_on_assigned_inspector_id"
    t.index ["homeowner_id"], name: "index_inspections_on_homeowner_id"
    t.index ["inspection_request_id"], name: "index_inspections_on_inspection_request_id"
    t.index ["office_id"], name: "index_inspections_on_office_id"
    t.index ["organization_id", "status"], name: "index_inspections_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_inspections_on_organization_id"
    t.index ["property_id"], name: "index_inspections_on_property_id"
    t.check_constraint "inspection_type::text = ANY (ARRAY['wind_mitigation'::character varying, 'four_point'::character varying, 'roof_condition'::character varying, 'general_home'::character varying, 'hoa_master_wind'::character varying, 'wind_type_ii'::character varying, 'wind_type_iii'::character varying]::text[])", name: "inspections_type_check"
    t.check_constraint "price_cents >= 0", name: "inspections_price_nonneg_check"
    t.check_constraint "status::text = ANY (ARRAY['unassigned'::character varying, 'assigned'::character varying, 'scheduled'::character varying, 'in_progress'::character varying, 'submitted_for_review'::character varying, 'approved'::character varying, 'delivered'::character varying, 'rejected'::character varying, 'cancelled'::character varying]::text[])", name: "inspections_status_check"
  end

  create_table "invoices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_id", null: false
    t.integer "amount_cents", null: false
    t.string "billing_mode", null: false
    t.datetime "created_at", null: false
    t.datetime "due_at"
    t.uuid "inspection_id", null: false
    t.uuid "organization_id", null: false
    t.string "status", default: "draft", null: false
    t.string "stripe_invoice_id"
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_invoices_on_agency_id"
    t.index ["inspection_id"], name: "index_invoices_on_inspection_id", unique: true
    t.index ["organization_id", "status"], name: "index_invoices_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_invoices_on_organization_id"
    t.index ["stripe_invoice_id"], name: "index_invoices_on_stripe_invoice_id", unique: true, where: "(stripe_invoice_id IS NOT NULL)"
    t.check_constraint "amount_cents >= 0", name: "invoices_amount_cents_nonneg_check"
    t.check_constraint "billing_mode::text = ANY (ARRAY['fixed_rate'::character varying, 'commission'::character varying]::text[])", name: "invoices_billing_mode_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'sent'::character varying, 'paid'::character varying, 'void'::character varying]::text[])", name: "invoices_status_check"
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

  create_table "payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.uuid "invoice_id", null: false
    t.string "method", default: "card", null: false
    t.uuid "organization_id", null: false
    t.datetime "paid_at"
    t.string "stripe_payment_intent_id"
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_payments_on_invoice_id"
    t.index ["organization_id"], name: "index_payments_on_organization_id"
    t.index ["stripe_payment_intent_id"], name: "index_payments_on_stripe_payment_intent_id", unique: true, where: "(stripe_payment_intent_id IS NOT NULL)"
    t.check_constraint "amount_cents >= 0", name: "payments_amount_cents_nonneg_check"
    t.check_constraint "method::text = ANY (ARRAY['card'::character varying, 'cash'::character varying, 'ach'::character varying]::text[])", name: "payments_method_check"
  end

  create_table "properties", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address", null: false
    t.string "city"
    t.string "county"
    t.datetime "created_at", null: false
    t.decimal "lat", precision: 10, scale: 6
    t.decimal "lng", precision: 10, scale: 6
    t.string "normalized_address", null: false
    t.uuid "organization_id", null: false
    t.string "state", limit: 2, default: "FL"
    t.string "structure_type"
    t.datetime "updated_at", null: false
    t.integer "year_built"
    t.string "zip"
    t.index ["organization_id", "normalized_address"], name: "index_properties_on_organization_id_and_normalized_address", unique: true
    t.index ["organization_id"], name: "index_properties_on_organization_id"
    t.check_constraint "structure_type IS NULL OR (structure_type::text = ANY (ARRAY['single_family'::character varying, 'condo'::character varying, 'hoa_master'::character varying, 'commercial'::character varying, 'mobile'::character varying]::text[]))", name: "properties_structure_type_check"
  end

  create_table "reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.jsonb "delivered_to", default: [], null: false
    t.datetime "generated_at", null: false
    t.uuid "inspection_id", null: false
    t.uuid "organization_id", null: false
    t.string "s3_key", null: false
    t.datetime "updated_at", null: false
    t.index ["inspection_id"], name: "index_reports_on_inspection_id", unique: true
    t.index ["organization_id"], name: "index_reports_on_organization_id"
    t.index ["s3_key"], name: "index_reports_on_s3_key", unique: true
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

  create_table "webhook_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "external_id"], name: "index_webhook_events_on_provider_and_external_id", unique: true
  end

  add_foreign_key "agencies", "organizations"
  add_foreign_key "agency_users", "agencies"
  add_foreign_key "agency_users", "organizations"
  add_foreign_key "homeowners", "organizations"
  add_foreign_key "inspection_events", "inspections"
  add_foreign_key "inspection_events", "organizations"
  add_foreign_key "inspection_requests", "agencies"
  add_foreign_key "inspection_requests", "agency_users", column: "submitted_by_agency_user_id"
  add_foreign_key "inspection_requests", "homeowners"
  add_foreign_key "inspection_requests", "organizations"
  add_foreign_key "inspection_requests", "properties"
  add_foreign_key "inspection_type_configs", "organizations"
  add_foreign_key "inspections", "agencies"
  add_foreign_key "inspections", "homeowners"
  add_foreign_key "inspections", "inspection_requests"
  add_foreign_key "inspections", "offices"
  add_foreign_key "inspections", "organizations"
  add_foreign_key "inspections", "properties"
  add_foreign_key "inspections", "users", column: "assigned_inspector_id"
  add_foreign_key "offices", "organizations"
  add_foreign_key "properties", "organizations"
  add_foreign_key "users", "offices"
  add_foreign_key "users", "organizations"
end
