# ## Schema Information
#
# Table name: `join_links`
#
# ### Columns
#
# Name                | Type               | Attributes
# ------------------- | ------------------ | ---------------------------
# **`id`**            | `integer`          | `not null, primary key`
# **`token_digest`**  | `string`           | `not null`
# **`created_at`**    | `datetime`         | `not null`
# **`updated_at`**    | `datetime`         | `not null`
# **`group_id`**      | `integer`          | `not null`
#
# ### Indexes
#
# * `index_join_links_on_group_id` (_unique_):
#     * **`group_id`**
# * `index_join_links_on_token_digest` (_unique_):
#     * **`token_digest`**
#
# ### Foreign Keys
#
# * `group_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`group_id => groups.id`**
#
# One group's shareable way in. The row existing is the link being on, so turning it off deletes the row and regenerating replaces it, and every link minted before either resolves to nothing.
#
# WHY: only the digest is stored, so a database read leaks no live link (#445 N1). The digest scheme is `Redeemable`'s, but not the concern itself, which is single-use and expires in fifteen minutes by construction, where a join link is shared with a whole group and lives until an owner retires it.
class JoinLink < ApplicationRecord
  TOKEN_BYTES = Redeemable::TOKEN_BYTES

  belongs_to :group

  class << self
    # Returns the raw token, which is the only moment it exists outside the owner's clipboard.
    def mint(group)
      SecureRandom.urlsafe_base64(TOKEN_BYTES).tap do |token|
        transaction do
          where(group:).delete_all
          create!(group:, token_digest: digest(token))
        end
      end
    end

    def find_by_token(token)
      find_by(token_digest: digest(token)) if token.is_a?(String) && token.present?
    end

    def digest(token)
      OpenSSL::HMAC.hexdigest("SHA256", hmac_key, token)
    end

    private
      def hmac_key
        Rails.application.key_generator.generate_key("#{name} token digest", 32)
      end
  end
end
