class CreateGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :groups do |t|
      t.string  :name,        null: false, limit: 250
      t.text    :description, null: true,  limit: 100_000 # bytes
      t.integer :group_type,  null: false

      t.timestamps
    end
  end
end
