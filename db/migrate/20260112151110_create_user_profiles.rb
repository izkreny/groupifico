class CreateUserProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_profiles do |t|
      t.string :first_name,   limit: 250
      t.string :last_name,    limit: 250
      t.string :mobile_phone, limit: 50
      t.belongs_to :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade, on_update: :cascade }

      t.timestamps
    end

    add_index :user_profiles, :mobile_phone, unique: true
  end
end
