# ## Schema Information
#
# Table name: `groups`
#
# ### Columns
#
# Name               | Type               | Attributes
# ------------------ | ------------------ | ---------------------------
# **`id`**           | `integer`          | `not null, primary key`
# **`description`**  | `text(100000)`     |
# **`group_type`**   | `integer`          | `not null`
# **`name`**         | `string(250)`      | `not null`
# **`created_at`**   | `datetime`         | `not null`
# **`updated_at`**   | `datetime`         | `not null`
# **`address_id`**   | `integer`          |
#
# ### Foreign Keys
#
# * `address_id` (_ON DELETE => restrict ON UPDATE => cascade_):
#     * **`address_id => addresses.id`**
#
class Group < ApplicationRecord
  belongs_to :address, optional: true, touch: true
  accepts_nested_attributes_for :address, reject_if: -> { it.values.all?(&:empty?) }
  has_many :members, dependent: :destroy
  has_many :events, dependent: :destroy
  # TODO: add order by `counter_cache` aka Adress field `events_count`
  has_many :events_addresses, -> { distinct }, through: :events, source: :address

  enum :group_type, %i[ general choir band ], default: :choir, validate: true

  validates_associated :address
  validates :name, presence: true, length: { maximum: 250 }
  validates :description, length: { maximum: 25_000 }

  def addresses
    Address.where(id: events.select(:address_id)).or(Address.where(id: address_id))
  end

  # Asked before a group loses an owner, by whichever end is losing one - the member being removed,
  # or the role being revoked. Kept here because "does this group still have an owner" is a fact
  # about the group, and both callers would otherwise write the same join.
  def owned_by_anyone_but?(member)
    members.joins(:roles).where(roles: { name: Role::OWNER }).where.not(id: member.id).exists?
  end
end
