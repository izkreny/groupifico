class ChangeColumnsOnEvents < ActiveRecord::Migration[8.1]
  def change
    change_table :events do |t|
      t.rename :start,      :starts_at
      t.rename :end,        :ends_at
      t.remove :event_type
      t.integer :category
    end
  end
end
