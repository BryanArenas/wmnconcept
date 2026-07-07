class CreateInspectionEvents < ActiveRecord::Migration[8.1]
  def change
    # Append-only timeline for an inspection (spec §6 side effects + §8.14
    # Timeline). Every §6 transition writes one row here. Internal, never
    # individually URL-addressable (it renders bundled in the inspection detail),
    # so a bigint PK per the §0 PK rule.
    create_table :inspection_events do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: true
      t.references :inspection, null: false, type: :uuid, foreign_key: true, index: true

      # Who caused it. Not a true polymorphic association — actors span two tables
      # (users, agency_users) and system events have none — so we store the class
      # name, uuid, and a denormalized label for display without an extra join.
      t.string :actor_type
      t.uuid :actor_id
      t.string :actor_label

      # Machine kind (e.g. "assigned", "rejected", "cancelled") + the status edge
      # it represents, for rendering the dot and grouping.
      t.string :kind, null: false
      t.string :from_status
      t.string :to_status
      # Human line shown in the timeline, e.g. "Assigned to Ivan Inspector".
      t.string :message, null: false
      t.jsonb :metadata, null: false, default: {}

      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :inspection_events, [:inspection_id, :occurred_at]
  end
end
