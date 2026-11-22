class CreateMemberStatusChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :member_status_changes do |t|
      t.belongs_to :member,    null: false, index: false, foreign_key: { on_delete: :cascade, on_update: :cascade }
      t.integer    :status,    null: false
      t.date       :starts_on, null: false
      # WHY: nullified rather than cascaded, so a removed member's changes to other members' histories stay, only without their author.
      t.belongs_to :updater, foreign_key: { to_table: :members, on_delete: :nullify, on_update: :cascade }

      t.timestamps
    end

    add_index :member_status_changes, [ :member_id, :starts_on ], unique: true
  end
end
