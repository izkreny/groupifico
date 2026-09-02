# ## Schema Information
#
# Table name: `sign_in_tokens`
#
# ### Columns
#
# Name                | Type               | Attributes
# ------------------- | ------------------ | ---------------------------
# **`id`**            | `integer`          | `not null, primary key`
# **`consumed_at`**   | `datetime`         |
# **`expires_at`**    | `datetime`         | `not null`
# **`token_digest`**  | `string`           | `not null`
# **`created_at`**    | `datetime`         | `not null`
# **`updated_at`**    | `datetime`         | `not null`
# **`user_id`**       | `integer`          | `not null`
#
# ### Indexes
#
# * `index_sign_in_tokens_on_token_digest` (_unique_):
#     * **`token_digest`**
# * `index_sign_in_tokens_on_user_id`:
#     * **`user_id`**
#
# ### Foreign Keys
#
# * `user_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`user_id => users.id`**
#
class SignInToken < ApplicationRecord
  include Redeemable

  belongs_to :user

  class << self
    # The one column this table has beyond the credential, so the caller names it positionally and
    # the concern's keyword form stays the general one.
    def mint(user) = super(user: user)

    def redeem!(token)
      spent = spend!(token)

      spent.user.tap { it.sign_in_tokens.consume_all(at: spent.consumed_at) }
    end
  end
end
