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
class UserProfile < ApplicationRecord
  belongs_to :user

  validates :first_name, :last_name, length: { maximum: 250 }
  validates :mobile_phone, uniqueness: true, length: { maximum: 50 }
end
