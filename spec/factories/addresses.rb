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
FactoryBot.define do
  factory :address do
    name { Faker::TvShows::Simpsons.location }

    trait :with_all_attributes do
      street_name     { Faker::Address.street_name }
      building_number { Faker::Address.building_number }
      city            { Faker::Address.city }
      postal_code     { Faker::Address.zip_code }
      state_code      { Faker::Address.state_abbr }
      country_code    { Faker::Address.country_code }
      latitude        { Faker::Address.latitude }
      longitude       { Faker::Address.longitude }
    end
  end
end
