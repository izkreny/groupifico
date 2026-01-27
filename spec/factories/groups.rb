# ## Schema Information
#
# Table name: `groups`
#
# ### Columns
#
# Name               | Type               | Attributes
# ------------------ | ------------------ | ---------------------------
# **`id`**           | `integer`          | `not null, primary key`
# **`description`**  | `text(100000)`     |
# **`group_type`**   | `integer`          | `not null`
# **`name`**         | `string(250)`      | `not null`
# **`created_at`**   | `datetime`         | `not null`
# **`updated_at`**   | `datetime`         | `not null`
# **`address_id`**   | `integer`          |
#
# ### Foreign Keys
#
# * `address_id` (_ON DELETE => restrict ON UPDATE => cascade_):
#     * **`address_id => addresses.id`**
#
FactoryBot.define do
  factory :group do
    name { Faker::App.name }

    trait :with_all_attributes do
      description { Faker::Lorem.paragraph }
      association :address, :with_all_attributes
    end
  end
end
