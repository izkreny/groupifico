class CreateFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :feedbacks do |t|
      t.belongs_to :user,         null: false, foreign_key: { on_delete: :cascade, on_update: :cascade }
      t.text       :description,  null: false
      t.json       :context,      null: false, default: {}
      t.integer    :issue_number

      t.timestamps
    end
  end
end
