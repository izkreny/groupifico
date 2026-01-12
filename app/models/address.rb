# == Schema Information
#
# Table name: addresses
#
#  id              :integer          not null, primary key
#  building_number :string(250)
#  city            :string(250)
#  country_code    :string(5)
#  latitude        :float
#  longitude       :float
#  name            :string(250)      not null
#  postal_code     :string(100)
#  state_code      :string(50)
#  street_name     :string(250)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Address < ApplicationRecord
  has_many :events
  has_many :groups
end
