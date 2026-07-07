class CreateInspectionRequests < ActiveRecord::Migration[8.1]
  INSPECTION_TYPES = %w[
    wind_mitigation four_point roof_condition general_home
    hoa_master_wind wind_type_ii wind_type_iii
  ].freeze
  STATUSES = %w[submitted accepted declined].freeze

  def change
    # Agency intake (spec §3, §8.2). One request can name several inspection
    # types; accepting it spawns one inspection per type (spec §8.7). UUID PK.
    create_table :inspection_requests, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: true
      t.references :agency, null: false, type: :uuid, foreign_key: true, index: true
      # The partner who submitted it. Nullable: staff may intake on an agency's
      # behalf, and we never want to lose the request if the user is later removed.
      t.references :submitted_by_agency_user, type: :uuid,
                                              foreign_key: { to_table: :agency_users }, index: true
      t.references :property, null: false, type: :uuid, foreign_key: true, index: true
      t.references :homeowner, null: false, type: :uuid, foreign_key: true, index: true

      # The requested inspection types (array of the §11 type keys).
      t.string :requested_types, array: true, null: false, default: []
      # Free text or a date-range string (spec §8.2).
      t.string :preferred_dates
      t.text :notes

      t.string :status, null: false, default: "submitted"
      # Populated only when declined (spec §8.7 — decline needs a reason).
      t.text :decline_reason

      t.timestamps
    end

    # Triage queries filter by status within a tenant (spec §8.7 index).
    add_index :inspection_requests, [:organization_id, :status]

    add_check_constraint :inspection_requests,
                         "status IN (#{STATUSES.map { |s| "'#{s}'" }.join(', ')})",
                         name: "inspection_requests_status_check"
    # At least one type, and every element must be a known inspection type.
    add_check_constraint :inspection_requests,
                         "array_length(requested_types, 1) >= 1",
                         name: "inspection_requests_types_present_check"
    add_check_constraint :inspection_requests,
                         "requested_types <@ ARRAY" \
                         "[#{INSPECTION_TYPES.map { |t| "'#{t}'" }.join(', ')}]::varchar[]",
                         name: "inspection_requests_types_valid_check"
  end
end
