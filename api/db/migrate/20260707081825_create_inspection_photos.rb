class CreateInspectionPhotos < ActiveRecord::Migration[8.1]
  def change
    # UUID PK — photos are addressed by URL/API (spec §0).
    create_table :inspection_photos, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :inspection_id, null: false
      t.string :s3_key, null: false
      # pending → uploaded (confirmed by client after PUT to presigned URL completes)
      t.string :upload_state, null: false, default: "pending"
      t.string :filename
      t.string :content_type

      t.timestamps
    end

    add_index :inspection_photos, :organization_id
    add_index :inspection_photos, :inspection_id
    add_index :inspection_photos, [:inspection_id, :upload_state],
              name: "index_inspection_photos_on_inspection_and_state"
    add_index :inspection_photos, :s3_key, unique: true

    add_check_constraint :inspection_photos,
                         "upload_state IN ('pending','uploaded')",
                         name: "inspection_photos_upload_state_check"
  end
end
