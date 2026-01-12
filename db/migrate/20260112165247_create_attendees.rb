class CreateAttendees < ActiveRecord::Migration[8.1]
  def change
    create_table :attendees do |t|
      t.belongs_to :member, null: false, foreign_key: { on_delete: :cascade, on_update: :cascade }
      t.belongs_to :event,  null: false, foreign_key: { on_delete: :cascade, on_update: :cascade }
      t.integer    :status, null: false

      t.timestamps
    end

    add_index :attendees, [ :member_id, :event_id ], unique: true
  end
end
