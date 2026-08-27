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

  # Every address this group can reach: its own, plus its events'. A relation rather than the
  # array a union produced, so callers can ask the database instead of loading every row and
  # filtering in Ruby - `event_params` checks a submitted address_id against this set on every
  # write, and `where id IN` is the query for that. Duplicates cannot arise, so the `distinct`
  # that `events_addresses` carries is not needed here.
  #
  # `where(id: nil)` matches nothing, so a group with no address of its own needs no branch.
  def addresses
    Address.where(id: events.select(:address_id)).or(Address.where(id: address_id))
  end
end
