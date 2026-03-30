# ## Schema Information
#
# Table name: `events`
#
# ### Columns
#
# Name               | Type               | Attributes
# ------------------ | ------------------ | ---------------------------
# **`id`**           | `integer`          | `not null, primary key`
# **`category`**     | `integer`          |
# **`description`**  | `text(100000)`     |
# **`ends_at`**      | `datetime`         | `not null`
# **`name`**         | `string(250)`      | `not null`
# **`starts_at`**    | `datetime`         | `not null`
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
  accepts_nested_attributes_for :address, reject_if: -> { it.values.all?(&:empty?) }
  belongs_to :creator, class_name: "Member", foreign_key: "creator_id", inverse_of: :created_events
  belongs_to :manager, class_name: "Member", foreign_key: "manager_id", inverse_of: :managed_events, optional: true
  has_many :registrations, dependent: :destroy
  has_many :attendees, through: :registrations, source: :member

  enum :status, %i[ unconfirmed confirmed concluded canceled ], default: :unconfirmed, validate: true
  enum :category, %i[ other rehearsal gig ], default: :other, validate: true

  validates_associated :address, :manager
  validates :name, :starts_at, presence: true
  validates :name, length: { maximum: 250 }
  validates :description, length: { maximum: 25_000 }
  validates :ends_at, comparison: { greater_than: :starts_at }

  scope :upcoming, -> { where(starts_at: Time.now..) }
  scope :ongoing,  -> { where(starts_at: ...Time.now).where(ends_at: Time.now..) }
  scope :past,     -> { where(ends_at: ...Time.now) }

  # TODO: add event's time_zone context
  def same_day?
    starts_at.to_date == ends_at.to_date
  end

  def shift_by(duration)
    self.starts_at += duration
    self.ends_at   += duration

    self
  end

  def duplicate
    raise ArgumentError, "Unable to duplicate the event!" unless self.duplicable?
    event        = self.dup
    event.status = "unconfirmed" unless event.unconfirmed?

    event
  end
end
