class CreateInspectionFormResponses < ActiveRecord::Migration[8.1]
  def change
    # bigint PK — internal join table, not URL-reachable (spec §0).
    create_table :inspection_form_responses do |t|
      t.uuid :organization_id, null: false
      t.uuid :inspection_id, null: false
      # Free-form responses keyed by template field key. Shape: { key => value }
      t.jsonb :responses, null: false, default: {}

      t.timestamps
    end

    add_index :inspection_form_responses, :organization_id
    add_index :inspection_form_responses, :inspection_id, unique: true
  end
end
