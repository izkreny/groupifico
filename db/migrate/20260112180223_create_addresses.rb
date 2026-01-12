class CreateAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :addresses do |t|
      t.string :name,            limit: 250, null: false
      t.string :street_name,     limit: 250
      t.string :building_number, limit: 250
      t.string :city,            limit: 250
      t.string :postal_code,     limit: 100
      t.string :state_code,      limit: 50
      t.string :country_code,    limit: 5
      t.float  :latitude
      t.float  :longitude

      t.timestamps
    end
  end
end
