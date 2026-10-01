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

  # The roles join, in one place, because both ends of the ownership invariant ask it: the group,
  # for whether anyone else still owns it, and the user, for which groups would be left without an
  # owner. Two spellings of one join are two places a later role change has to find.
  scope :owners, -> { joins(:roles).where(roles: { name: Role::OWNER }) }

  # Members with no registration on the event, never invited or taken off. The whole of what it
  # decides, so each caller states its own status rule beside it rather than inheriting one the
  # name does not mention: the invitation screen keeps paused members, who are listed and cannot
  # be ticked, and the create behind it takes `active` alone.
  #
  # Here rather than in `RegistrationsHelper` because both ask it, and two spellings of one rule
  # are two places a later change has to find.
  scope :without_registration_for, ->(event) {
    where.not(id: event.registrations.select(:member_id))
  }

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

  # A membership is created for an address, which is how an owner or an administrator names
  # somebody they are adding. An address no account holds yet builds the user, and `belongs_to`
  # saves it inside this record's own save, so the user and the membership land together or not
  # at all. `find_or_initialize_by` applies `User`'s normalization to the lookup, so a differently
  # cased address finds the account it belongs to.
  def email=(address)
    self.user = User.find_or_initialize_by(email: address)
  end

  # WHY: `belongs_to` saves a new user in `before_save`, after this record has already passed its
  # own validation, so an address `User` refuses would reach the INSERT with a nil `user_id` and
  # answer a database exception rather than a form error. Asking the user here puts its verdict on
  # the field the form drew, and leaves `User` the one place the rules for an address live.
  validate :new_user_is_valid, on: :create, if: -> { user&.new_record? }

  # The unique index on `user_id` and `group_id` already refuses a second membership, but as an
  # exception. This is the same rule with a message, on the field the person typed into, and it
  # guards every save rather than only the form's, so a membership moved onto a user the group
  # already holds is refused the same way. Every status counts, an `inactive` one included:
  # setting a status back is the member page's job.
  validate :not_already_in_the_group

  delegate :email, to: :user, allow_nil: true
  delegate :full_name, :short_name, to: :profile

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
    def new_user_is_valid
      return if user.valid?

      user.errors.where(:email).each { errors.add(:email, it.message) }
    end

    def not_already_in_the_group
      return unless user&.persisted? && group&.persisted?

      errors.add(:email, "already belongs to a member of this group") if group.members.where.not(id:).exists?(user:)
    end

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
