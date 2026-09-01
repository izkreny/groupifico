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
  # Everything that is not a live, unspent link raises this one error: a blank or malformed value,
  # a digest no row carries, a link already spent, a link past its expiry. They are deliberately
  # indistinguishable to the caller, and the typed error is what keeps a malformed value from
  # arriving as a `TypeError` out of the digest call instead.
  class InvalidToken < StandardError; end

  EXPIRES_IN = 15.minutes

  # 32 bytes is 256 bits, twice what #139 asks for. `SecureRandom.urlsafe_base64` draws with
  # replacement; the `Array#sample` generator ADR 0004 found in `mikker/passwordless` does not,
  # which is how a nominally 36^6 keyspace turned out to be about 2^30.
  TOKEN_BYTES = 32

  belongs_to :user

  scope :outstanding, -> { where(consumed_at: nil) }

  class << self
    # Returns the raw token, which is the only moment it exists outside the email. Nothing stores
    # it: the row carries its digest.
    def mint(user)
      SecureRandom.urlsafe_base64(TOKEN_BYTES).tap do |token|
        create!(user: user, token_digest: digest(token), expires_at: EXPIRES_IN.from_now)
      end
    end

    def redeem!(token)
      raise InvalidToken unless token.is_a?(String) && token.present?

      now    = Time.current
      wanted = digest(token)

      # One conditional UPDATE, acting on the number of rows it changed. Reading the row, comparing
      # in Ruby and then updating it by id is a time-of-check gap that two concurrent redemptions
      # both pass; there is no separate read here to race against. ADR 0004 records the rodauth
      # release that had to close exactly that gap.
      spent = outstanding.where(token_digest: wanted, expires_at: now..)
                         .update_all(consumed_at: now, updated_at: now)
      raise InvalidToken if spent.zero?

      # Safe to read only because the row is already spent: whatever else raced for it has lost.
      find_by!(token_digest: wanted).user.tap { it.sign_in_tokens.consume_all(at: now) }
    end

    # Deterministic, so a lookup by digest is an indexed single-row read and the link needs to
    # carry no account id for one. Keyed off `secret_key_base` through the key generator, so there
    # is no new secret to manage and rotation has rodauth's fallback pattern available.
    def digest(token)
      OpenSSL::HMAC.hexdigest("SHA256", hmac_key, token)
    end

    def consume_all(at: Time.current)
      outstanding.update_all(consumed_at: at, updated_at: at)
    end

    private
      def hmac_key
        Rails.application.key_generator.generate_key("SignInToken token digest", 32)
      end
  end
end
