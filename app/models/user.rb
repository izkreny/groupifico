# ## Schema Information
#
# Table name: `users`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`email`**       | `string(250)`      | `not null`
# **`created_at`**  | `datetime`         | `not null`
# **`updated_at`**  | `datetime`         | `not null`
#
# ### Indexes
#
# * `index_users_on_email` (_unique_):
#     * **`email`**
#
class User < ApplicationRecord
  has_one :profile, class_name: "UserProfile", dependent: :destroy
  has_many :members, dependent: :destroy
  has_many :groups, through: :members

  validates :email, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 250 }, format: { with: URI::MailTo::EMAIL_REGEXP }
end
