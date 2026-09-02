# ## Schema Information
#
# Table name: `sign_ups`
#
# ### Columns
#
# Name                | Type               | Attributes
# ------------------- | ------------------ | ---------------------------
# **`id`**            | `integer`          | `not null, primary key`
# **`consumed_at`**   | `datetime`         |
# **`email`**         | `string(250)`      | `not null`
# **`expires_at`**    | `datetime`         | `not null`
# **`group_name`**    | `string(250)`      | `not null`
# **`token_digest`**  | `string`           | `not null`
# **`created_at`**    | `datetime`         | `not null`
# **`updated_at`**    | `datetime`         | `not null`
#
# ### Indexes
#
# * `index_sign_ups_on_token_digest` (_unique_):
#     * **`token_digest`**
#
class SignUp < ApplicationRecord
  include Redeemable

  # Matching `User`'s normalization exactly, because confirmation resolves the address through
  # `User.find_or_create_by!` and the two have to be comparing one spelling of it.
  normalizes :email, with: ->(email) { email.strip.downcase }

  # Stated here because nothing upstream enforces them. No Rails facility covers a token that
  # belongs to no record - `ActiveRecord::TokenFor` builds its payload from `model.id` and
  # re-derives the record from it, so a framework token always names a row that already exists.
  #
  # The format check is not decoration: an address that passes the form but fails `User`'s own
  # validation would take the link to a transaction that can never commit, and the person holding
  # it would have no way to learn why.
  validates :email, presence: true, length: { maximum: 250 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :group_name, presence: true, length: { maximum: 250 }

  class << self
    # The whole of the sign-up, in one transaction that contains the spend. Returns the `Member` it
    # created, which carries both the user to sign in and the group to land them on - the same
    # shape `SignInToken.redeem!` hands its controller.
    #
    # `spend!` is inside rather than before, so a validation failure anywhere rolls the spend back
    # and leaves the link live for a retry instead of burning it.
    def redeem!(token)
      transaction do
        spent  = spend!(token)
        user   = User.find_or_create_by!(email: spent.email)
        group  = Group.new(name: spent.group_name)
        member = group.add_owner(user)

        group.save!

        # There is a session from here on, so the account's outstanding sign-in links are consumed
        # exactly as `SignInToken.redeem!` consumes them. The address's other outstanding
        # `sign_ups` rows are deliberately left alone: each carries a different group name and a
        # different intent, so confirming one must not silently discard the rest.
        user.sign_in_tokens.consume_all(at: spent.consumed_at)

        member
      end
    end
  end
end
