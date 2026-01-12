class AddAddressReferenceToGroups < ActiveRecord::Migration[8.1]
  def change
    add_belongs_to :groups, :address, null: true, index: false, foreign_key: { on_delete: :restrict, on_update: :cascade }
  end
end
