# ## Schema Information
#
# Table name: `members`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`status`**      | `integer`          | `not null`
# **`created_at`**  | `datetime`         | `not null`
# **`updated_at`**  | `datetime`         | `not null`
# **`group_id`**    | `integer`          | `not null`
# **`user_id`**     | `integer`          | `not null`
#
# ### Indexes
#
# * `index_members_on_group_id`:
#     * **`group_id`**
# * `index_members_on_user_id`:
#     * **`user_id`**
# * `index_members_on_user_id_and_group_id` (_unique_):
#     * **`user_id`**
#     * **`group_id`**
#
# ### Foreign Keys
#
# * `group_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`group_id => groups.id`**
# * `user_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`user_id => users.id`**
#
class Member < ApplicationRecord
  belongs_to :user
  belongs_to :group
  has_one :profile, through: :user
  has_many :registrations, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :events, through: :registrations
  has_many :created_events, class_name: "Event", foreign_key: "creator_id", inverse_of: :creator
  has_many :managed_events, class_name: "Event", foreign_key: "manager_id", inverse_of: :manager

  enum :status, %i[ active paused inactive ], default: :active, validate: true

  # A group is never left without an owner, whoever is asking - the last owner acting on themselves
  # included, which is why this is here and not in a policy. `dependent: :destroy` rather than
  # `delete_all` on the roles above is what this costs: `delete_all` skips callbacks by definition,
  # so the guard on Role would never run.
  #
  # `prepend: true` is load-bearing. `has_many :roles, dependent: :destroy` registers its own
  # before_destroy when the association is declared, so without it the roles are destroyed first and
  # this guard asks `owner?` of a member who no longer holds anything - watched letting a group's
  # sole owner delete themselves.
  before_destroy :ensure_the_group_keeps_an_owner, prepend: true

  # The same invariant on the other move that reaches it. Removing the last owner and revoking their
  # role are both destructions and are guarded as such; leaving `active` is an ordinary update, and
  # without this a group's only owner could pause themselves and lock the group permanently - they
  # are then refused every write including the status write that would restore them, and nobody else
  # holds `can_manage?(:members)`. A validation rather than a `throw :abort` because this one has a
  # form to render the message on.
  validate :group_keeps_an_active_owner, on: :update

  delegate :full_name, to: :profile

  # The one question a policy asks. It learns nothing about how the answer is stored, which is what
  # lets a role arrive as a row rather than as a migration. `module_name` rather than `module`
  # because the latter is a keyword; a module the vocabulary carries no role for yet is answered by
  # `owner` and `administrator` alone, which is how it is governed until it gets one.
  def can_manage?(module_name)
    roles.any? { it.grants?(module_name) }
  end

  # The other question a policy asks, and the only one `can_manage?` cannot express: it admits an
  # administrator for every module, while the group's own rows belong to the owner alone. Asked of
  # the member rather than of `roles` for the same reason as above - where a role lives stays this
  # model's business.
  def owner? = roles.any?(&:owner?)

  private
    # Destroying the group destroys its members, and a group on its way out needs no owner.
    # `destroyed_by_association` is what tells the two cases apart.
    def group_keeps_an_active_owner
      return unless status_changed? && !active?
      return unless owner?
      return if group.owned_by_anyone_but?(self)

      errors.add(:status, "cannot leave the group without an active owner")
    end

    def ensure_the_group_keeps_an_owner
      return unless owner?
      return if destroyed_by_association
      return if group.owned_by_anyone_but?(self)

      throw :abort
    end
end
