class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string     :name,        null: false, limit: 250
      t.text       :description, null: true,  limit: 100_000 # bytes
      t.datetime   :start,       null: false
      t.datetime   :end,         null: false
      t.integer    :status,      null: false
      t.integer    :event_type,  null: false
      t.belongs_to :group,       null: false, foreign_key: { on_delete: :cascade, on_update: :cascade }

      t.timestamps
    end
  end
end
