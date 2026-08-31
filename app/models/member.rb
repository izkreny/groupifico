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
  has_many :roles, dependent: :delete_all
  has_many :events, through: :registrations
  has_many :created_events, class_name: "Event", foreign_key: "creator_id", inverse_of: :creator
  has_many :managed_events, class_name: "Event", foreign_key: "manager_id", inverse_of: :manager

  enum :status, %i[ active paused inactive ], default: :active, validate: true

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
end
