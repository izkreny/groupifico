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

  # Deleting the account takes every membership with it, so an account that is the last active owner
  # of a group would leave that group ownerless. `Member`'s own last-owner guard never fires on this
  # route: it returns early on `destroyed_by_association`, which any parent destroy sets, and it was
  # written for the one parent whose destruction makes an ownerless group harmless - the group's.
  #
  # `prepend: true` is load-bearing, the same trap that guard documents. `has_many :members,
  # dependent: :destroy` registers its own before_destroy when the association is declared, so
  # without it the memberships are destroyed first and this asks a user who no longer owns anything.
  before_destroy :ensure_no_group_loses_its_only_owner, prepend: true

  # Asked of the user rather than of the member, because the refusal has to name every group the
  # account would orphan and a member sees one group at a time. `active` and the owner role are what
  # `Group#owned_by_anyone_but?` counts on the other side, so the two ends agree on who an owner is.
  def solely_owned_groups
    members.active.joins(:roles).where(roles: { name: Role::OWNER }).includes(:group)
      .reject { it.group.owned_by_anyone_but?(it) }
      .map(&:group)
  end

  private
    def consume_outstanding_sign_in_tokens
      sign_in_tokens.consume_all
    end

    def ensure_no_group_loses_its_only_owner
      throw :abort if solely_owned_groups.any?
    end
end
