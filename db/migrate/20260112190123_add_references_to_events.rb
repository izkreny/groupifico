class AddReferencesToEvents < ActiveRecord::Migration[8.1]
  def change
    add_belongs_to :events, :address, null: true, index: false, foreign_key: { on_delete: :restrict, on_update: :cascade }
    add_column :events, :creator_id, :bigint, null: false
    add_column :events, :manager_id, :bigint, null: true
  end
end
