# ## Schema Information
#
# Table name: `events`
#
# ### Columns
#
# Name               | Type               | Attributes
# ------------------ | ------------------ | ---------------------------
# **`id`**           | `integer`          | `not null, primary key`
# **`description`**  | `text(100000)`     |
# **`end`**          | `datetime`         | `not null`
# **`event_type`**   | `integer`          | `not null`
# **`name`**         | `string(250)`      | `not null`
# **`start`**        | `datetime`         | `not null`
# **`status`**       | `integer`          | `not null`
# **`created_at`**   | `datetime`         | `not null`
# **`updated_at`**   | `datetime`         | `not null`
# **`address_id`**   | `integer`          |
# **`creator_id`**   | `bigint`           | `not null`
# **`group_id`**     | `integer`          | `not null`
# **`manager_id`**   | `bigint`           |
#
# ### Indexes
#
# * `index_events_on_group_id`:
#     * **`group_id`**
#
# ### Foreign Keys
#
# * `address_id` (_ON DELETE => restrict ON UPDATE => cascade_):
#     * **`address_id => addresses.id`**
# * `group_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`group_id => groups.id`**
#
class Event < ApplicationRecord
  belongs_to :group
  belongs_to :address, optional: true, touch: true
  belongs_to :creator, class_name: "Member", foreign_key: "creator_id", inverse_of: :created_events
  belongs_to :manager, class_name: "Member", foreign_key: "manager_id", inverse_of: :managed_events, optional: true
  has_many :attendees, dependent: :destroy
  has_many :members, through: :attendees

  enum :status, %i[ unconfirmed confirmed concluded canceled ], default: :unconfirmed, validate: true
  enum :event_type, %i[ other rehearsal gig ], default: :rehearsal, validate: true

  validates_associated :address, :manager
  validates :name, :start, :end, presence: true
  validates :name, length: { maximum: 250 }
  validates :description, length: { maximum: 25_000 }
  validates :end, comparison: { greater_than: :start }
end
