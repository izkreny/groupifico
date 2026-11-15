# ## Schema Information
#
# Table name: `join_requests`
#
# ### Columns
#
# Name                | Type               | Attributes
# ------------------- | ------------------ | ---------------------------
# **`id`**            | `integer`          | `not null, primary key`
# **`consumed_at`**   | `datetime`         |
# **`email`**         | `string(250)`      | `not null`
# **`expires_at`**    | `datetime`         | `not null`
# **`first_name`**    | `string(250)`      | `not null`
# **`last_name`**     | `string(250)`      | `not null`
# **`mobile_phone`**  | `string(50)`       | `not null`
# **`token_digest`**  | `string`           | `not null`
# **`created_at`**    | `datetime`         | `not null`
# **`updated_at`**    | `datetime`         | `not null`
# **`join_link_id`**  | `integer`          | `not null`
#
# ### Indexes
#
# * `index_join_requests_on_join_link_id`:
#     * **`join_link_id`**
# * `index_join_requests_on_token_digest` (_unique_):
#     * **`token_digest`**
#
# ### Foreign Keys
#
# * `join_link_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`join_link_id => join_links.id`**
#
# A visitor's request to join a group through its join link, carrying the emailed token that confirms it. Nothing joins the group until #447 redeems it.
class JoinRequest < ApplicationRecord
  include Redeemable

  belongs_to :join_link

  # WHY: `User`'s normalization exactly, because confirming resolves the address to a user and the two must compare one spelling of it.
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, length: { maximum: 250 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, presence: true, length: { maximum: 250 }
  # WHY: shape only, an optional "+" then digits and the separators people type, because `UserProfile` checks no format yet; its uniqueness is left to confirmation, since refusing a taken number here would tell the visitor someone holds it.
  validates :mobile_phone, presence: true, length: { maximum: 50 }, format: { with: /\A\+?[\d ().-]{6,}\z/ }
end
