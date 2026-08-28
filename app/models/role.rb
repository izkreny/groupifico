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
  # policy change, because `Member#can_manage?` derives the name it looks for from the module.
  NAMES = %w[ owner administrator events_administrator songs_administrator ].freeze

  belongs_to :member

  # The list is read through a lambda rather than passed by value, so a spec that extends the
  # vocabulary is validated against the extension rather than against the value frozen at load.
  validates :name, inclusion: { in: ->(_role) { NAMES } }, uniqueness: { scope: :member_id }

  # Where `owner` implies `administrator`, and both imply every module role. One row per role a
  # member actually holds, and the implication lives here instead.
  def grants?(module_name)
    name.in?([ "owner", "administrator", "#{module_name}_administrator" ])
  end
end
