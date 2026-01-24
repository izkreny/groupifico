# ## Schema Information
#
# Table name: `addresses`
#
# ### Columns
#
# Name                   | Type               | Attributes
# ---------------------- | ------------------ | ---------------------------
# **`id`**               | `integer`          | `not null, primary key`
# **`building_number`**  | `string(250)`      |
# **`city`**             | `string(250)`      |
# **`country_code`**     | `string(5)`        |
# **`latitude`**         | `float`            |
# **`longitude`**        | `float`            |
# **`name`**             | `string(250)`      | `not null`
# **`postal_code`**      | `string(100)`      |
# **`state_code`**       | `string(50)`       |
# **`street_name`**      | `string(250)`      |
# **`created_at`**       | `datetime`         | `not null`
# **`updated_at`**       | `datetime`         | `not null`
#
class Address < ApplicationRecord
  has_many :events
  has_many :groups

  validates :name, presence: true
  validates :building_number, :city, :name, :street_name, length: { maximum: 250 }
  validates :postal_code, length: { maximum: 100 }
  validates :state_code, length: { maximum: 50 }
  validates :country_code, length: { maximum: 5 }
  validates :latitude, :longitude, numericality: true, allow_nil: true
end
