class CreateInspections < ActiveRecord::Migration[8.1]
  INSPECTION_TYPES = %w[
    wind_mitigation four_point roof_condition general_home
    hoa_master_wind wind_type_ii wind_type_iii
  ].freeze
  # The nine-state machine (spec §6). Stored, never derived.
  STATUSES = %w[
    unassigned assigned scheduled in_progress
    submitted_for_review approved delivered rejected cancelled
  ].freeze

  def change
    # The unit of work AND billing (spec §3, §6). One per requested type. UUID PK.
    # `status` is the stored §6 state machine; `price_cents` is snapshotted from
    # inspection_type_configs at accept time (spec §11 — never a baked constant).
    create_table :inspections, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: true
      t.references :inspection_request, null: false, type: :uuid, foreign_key: true, index: true
      t.references :agency, null: false, type: :uuid, foreign_key: true, index: true
      t.references :property, null: false, type: :uuid, foreign_key: true, index: true
      t.references :homeowner, null: false, type: :uuid, foreign_key: true, index: true
      # Set on `assign`; nullable until then.
      t.references :assigned_inspector, type: :uuid,
                                        foreign_key: { to_table: :users }, index: true
      # Which office owns the job; set at accept from the request/property.
      t.references :office, type: :bigint, foreign_key: true, index: true

      t.string :inspection_type, null: false
      t.datetime :scheduled_at
      t.string :status, null: false, default: "unassigned"
      # Snapshot of the fee at accept time so later price-sheet edits don't
      # retroactively re-price open work.
      t.integer :price_cents, null: false

      # Set on `reject` (spec §6 guard: note present). Cleared is fine on re-submit.
      t.text :rejection_note

      # Lifecycle stamps for the timeline + SLA reporting. Nullable; each is set
      # by its transition.
      t.datetime :started_at
      t.datetime :submitted_at
      t.datetime :approved_at
      t.datetime :delivered_at
      t.datetime :cancelled_at

      t.timestamps
    end

    # Spec §3 required indexes.
    add_index :inspections, [:organization_id, :status]
    add_index :inspections, [:assigned_inspector_id, :scheduled_at]

    add_check_constraint :inspections,
                         "inspection_type IN " \
                         "(#{INSPECTION_TYPES.map { |t| "'#{t}'" }.join(', ')})",
                         name: "inspections_type_check"
    add_check_constraint :inspections,
                         "status IN (#{STATUSES.map { |s| "'#{s}'" }.join(', ')})",
                         name: "inspections_status_check"
    add_check_constraint :inspections,
                         "price_cents >= 0",
                         name: "inspections_price_nonneg_check"
  end
end
