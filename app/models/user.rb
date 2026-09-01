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
  has_many :sessions, dependent: :destroy
  has_many :sign_in_tokens, dependent: :destroy
  has_one :profile, class_name: "UserProfile", dependent: :destroy
  has_many :members, dependent: :destroy
  has_many :groups, through: :members

  # `groups` is every group ever joined. A member whose status is `inactive` has left and is
  # refused exactly like a non-member, so the set anything may be authorized against is this one -
  # `active` and `paused` both still belong, and the read/write split between them is a rule
  # rather than a set. Every policy scope asks for this; none should ask for `groups`.
  has_many :current_memberships, -> { where.not(status: :inactive) },
    class_name: "Member", inverse_of: :user, dependent: nil
  has_many :current_groups, through: :current_memberships, source: :group

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 250 }, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_validation -> { build_profile unless profile }, on: :create
  validates :profile, presence: true, on: :create

  # An outstanding link signs in whoever holds it, and it was sent to an address this account no
  # longer answers to. Inside the transaction rather than after commit, so a rolled-back email
  # change takes the invalidation back with it. Consumed rather than deleted, keeping the record
  # of what was issued that ADR 0004 chose the row-per-request table for.
  after_update :consume_outstanding_sign_in_tokens, if: :saved_change_to_email?

  private
    def consume_outstanding_sign_in_tokens
      sign_in_tokens.consume_all
    end
end
