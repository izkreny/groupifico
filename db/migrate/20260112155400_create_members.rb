class CreateMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :members do |t|
      t.belongs_to :user,   null: false, foreign_key: { on_delete: :cascade, on_update: :cascade }
      t.belongs_to :group,  null: false, foreign_key: { on_delete: :cascade, on_update: :cascade }
      t.integer    :status, null: false
      t.integer    :role,   null: false

      t.timestamps
    end

    add_index :members, [ :user_id, :group_id ], unique: true
  end
end
