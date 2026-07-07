class CreateInspectionFormTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :inspection_form_templates do |t|
      t.uuid :organization_id, null: false
      t.string :inspection_type, null: false
      # JSON Schema describing the form fields for this type (§11 PLACEHOLDER).
      # Shape: { fields: [{ key, label, type, required, options }] }
      t.jsonb :schema, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :inspection_form_templates, :organization_id
    add_index :inspection_form_templates,
              [:organization_id, :inspection_type],
              unique: true,
              name: "index_form_templates_on_org_and_type"
    add_index :inspection_form_templates, [:organization_id, :position],
              name: "index_form_templates_on_org_and_position"
  end
end
