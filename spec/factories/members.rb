# ## Schema Information
#
# Table name: `members`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`role`**        | `integer`          | `not null`
# **`status`**      | `integer`          | `not null`
# **`created_at`**  | `datetime`         | `not null`
# **`updated_at`**  | `datetime`         | `not null`
# **`group_id`**    | `integer`          | `not null`
# **`user_id`**     | `integer`          | `not null`
#
# ### Indexes
#
# * `index_members_on_group_id`:
#     * **`group_id`**
# * `index_members_on_user_id`:
#     * **`user_id`**
# * `index_members_on_user_id_and_group_id` (_unique_):
#     * **`user_id`**
#     * **`group_id`**
#
# ### Foreign Keys
#
# * `group_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`group_id => groups.id`**
# * `user_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`user_id => users.id`**
#
FactoryBot.define do
  factory :member, aliases: [ :creator, :manager ] do
    user
    group

    trait :with_all_attributes do
      association :user,  :with_full_profile
      association :group, :with_all_attributes
    end
  end
end
