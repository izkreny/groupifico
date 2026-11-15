# ## Schema Information
#
# Table name: `join_links`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`token`**       | `string`           | `not null`
# **`created_at`**  | `datetime`         | `not null`
# **`updated_at`**  | `datetime`         | `not null`
# **`group_id`**    | `integer`          | `not null`
#
# ### Indexes
#
# * `index_join_links_on_group_id` (_unique_):
#     * **`group_id`**
# * `index_join_links_on_token` (_unique_):
#     * **`token`**
#
# ### Foreign Keys
#
# * `group_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`group_id => groups.id`**
#
# One group's shareable way in. The row existing is the link being on, so turning it off deletes the row and regenerating replaces it, and every link made before either resolves to nothing.
#
# WHY: the token is stored as it is, so an owner can copy the link for as long as it is on; the owner chose that over storing a digest on #453.
class JoinLink < ApplicationRecord
  belongs_to :group

  has_secure_token :token

  class << self
    # WHY: deleted before created rather than through `Group#create_join_link!`, which inserts the new row first and so trips the unique `group_id`.
    def mint(group)
      transaction do
        where(group:).delete_all
        create!(group:)
      end.token
    end

    def find_by_token(token)
      find_by(token:) if token.is_a?(String)
    end
  end
end
