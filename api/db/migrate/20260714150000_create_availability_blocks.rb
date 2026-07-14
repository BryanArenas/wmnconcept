class CreateAvailabilityBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :availability_blocks, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true, index: true
      t.references :organization, null: false, type: :uuid, foreign_key: true, index: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.boolean :all_day, null: false, default: false
      t.string :reason
      t.timestamps
    end

    add_index :availability_blocks, [:user_id, :starts_at]
  end
end
