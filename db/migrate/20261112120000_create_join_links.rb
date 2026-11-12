class CreateJoinLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :join_links do |t|
      t.belongs_to :group,        null: false, index: { unique: true }, foreign_key: { on_delete: :cascade, on_update: :cascade }
      t.string     :token_digest, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
