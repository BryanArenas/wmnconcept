class CreateReports < ActiveRecord::Migration[8.1]
  def change
    # UUID PK — the report is fetched by URL (signed download, spec §4/§8.4).
    create_table :reports, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :inspection_id, null: false
      t.string :s3_key, null: false
      t.datetime :generated_at, null: false
      t.datetime :delivered_at
      # Per-recipient delivery ledger (spec §3, §9). Shape:
      # [{ "email", "role", "status", "delivered_at" }]
      t.jsonb :delivered_to, null: false, default: []

      t.timestamps
    end

    add_index :reports, :organization_id
    # One report per inspection (spec §3 — inspection_id uniq).
    add_index :reports, :inspection_id, unique: true
    add_index :reports, :s3_key, unique: true
  end
end
