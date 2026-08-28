# ## Schema Information
#
# Table name: `roles`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`name`**        | `string`           | `not null`
# **`created_at`**  | `datetime`         | `not null`
# **`updated_at`**  | `datetime`         | `not null`
# **`member_id`**   | `integer`          | `not null`
#
# ### Indexes
#
# * `index_roles_on_member_id`:
#     * **`member_id`**
# * `index_roles_on_member_id_and_name` (_unique_):
#     * **`member_id`**
#     * **`name`**
#
# ### Foreign Keys
#
# * `member_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`member_id => members.id`**
#
FactoryBot.define do
  factory :role do
    member
    name { "owner" }
  end
end
