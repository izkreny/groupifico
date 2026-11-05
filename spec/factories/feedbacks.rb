# ## Schema Information
#
# Table name: `feedbacks`
#
# ### Columns
#
# Name                | Type               | Attributes
# ------------------- | ------------------ | ---------------------------
# **`id`**            | `integer`          | `not null, primary key`
# **`context`**       | `json`             | `not null`
# **`description`**   | `text`             | `not null`
# **`issue_number`**  | `integer`          |
# **`created_at`**    | `datetime`         | `not null`
# **`updated_at`**    | `datetime`         | `not null`
# **`user_id`**       | `integer`          | `not null`
#
# ### Indexes
#
# * `index_feedbacks_on_user_id`:
#     * **`user_id`**
#
# ### Foreign Keys
#
# * `user_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`user_id => users.id`**
#
FactoryBot.define do
  factory :feedback do
    user
    description { "The event list does not scroll on my phone." }
  end
end
