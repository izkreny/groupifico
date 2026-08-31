# ## Schema Information
#
# Table name: `roles`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`name`**        | `string`           | `not null`
# **`created_at`**  | `datetime`         | `not null`
# **`updated_at`**  | `datetime`         | `not null`
# **`member_id`**   | `integer`          | `not null`
#
# ### Indexes
#
# * `index_roles_on_member_id`:
#     * **`member_id`**
# * `index_roles_on_member_id_and_name` (_unique_):
#     * **`member_id`**
#     * **`name`**
#
# ### Foreign Keys
#
# * `member_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`member_id => members.id`**
#
class Role < ApplicationRecord
  # The vocabulary. A further module role is an entry here and nothing else: no migration, and no
  # policy change, because `Member#can_manage?` derives the name it looks for from the module. A
  # module gets its role when its model does, which is what admitted `members_administrator` and
  # what keeps a module whose model is still unwritten out of the list.
  NAMES = %w[ owner administrator events_administrator members_administrator ].freeze

  # Raised where a name outside the vocabulary has to stop the work rather than fail a validation:
  # `MembersController` refuses the request with it, because dropping the name instead would read
  # as "hold no roles" and revoke the ones the member has.
  UnknownName = Class.new(StandardError)

  belongs_to :member

  validates :name, inclusion: { in: NAMES }, uniqueness: { scope: :member_id }

  # Where `owner` implies `administrator`, and both imply every module role. One row per role a
  # member actually holds, and the implication lives here instead.
  def grants?(module_name)
    name.in?([ "owner", "administrator", "#{module_name}_administrator" ])
  end

  # The question above cannot ask this one. It admits `administrator` for every module, so no
  # module name distinguishes the two, and several rows of the capability table are the owner's
  # alone - editing the group, deleting it, and granting a role.
  def owner? = name == "owner"
end
