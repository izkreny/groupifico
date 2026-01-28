# ## Schema Information
#
# Table name: `user_profiles`
#
# ### Columns
#
# Name                | Type               | Attributes
# ------------------- | ------------------ | ---------------------------
# **`id`**            | `integer`          | `not null, primary key`
# **`first_name`**    | `string(250)`      |
# **`last_name`**     | `string(250)`      |
# **`mobile_phone`**  | `string(50)`       |
# **`created_at`**    | `datetime`         | `not null`
# **`updated_at`**    | `datetime`         | `not null`
# **`user_id`**       | `integer`          | `not null`
#
# ### Indexes
#
# * `index_user_profiles_on_mobile_phone` (_unique_):
#     * **`mobile_phone`**
# * `index_user_profiles_on_user_id` (_unique_):
#     * **`user_id`**
#
# ### Foreign Keys
#
# * `user_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`user_id => users.id`**
#
FactoryBot.define do
  factory :user_profile do
    user

    trait :with_all_attributes do
      first_name   { Faker::Name.first_name }
      last_name    { Faker::Name.last_name }
      mobile_phone { Faker::PhoneNumber.unique.cell_phone_in_e164 }
    end
  end
end
