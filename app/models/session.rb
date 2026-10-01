# ## Schema Information
#
# Table name: `sessions`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`ip_address`**  | `string`           |
# **`user_agent`**  | `string`           |
# **`created_at`**  | `datetime`         | `not null`
# **`updated_at`**  | `datetime`         | `not null`
# **`user_id`**     | `integer`          | `not null`
#
# ### Indexes
#
# * `index_sessions_on_user_id`:
#     * **`user_id`**
#
# ### Foreign Keys
#
# * `user_id`:
#     * **`user_id => users.id`**
#
class Session < ApplicationRecord
  belongs_to :user

  # WHY: a session is what signing in makes, so its creation is the one moment both routes in pass
  # through - redeeming a sign-in link and confirming a sign-up. The roster reads the timestamp to
  # tell an owner which members they added have never signed in.
  after_create :record_first_sign_in

  private
    def record_first_sign_in
      user.touch(:first_signed_in_at) unless user.first_signed_in_at?
    end
end
