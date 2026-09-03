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

  # Derived from the event's own group rather than from a `Current.member`, which only the
  # controllers that set it could answer and which would read `nil` under every other: `group` is
  # already on the record by the time the default's `before_validation` runs.
  #
  # `new_record?` keeps it a create-time fill. The callback is unconditional and writes whatever
  # the lambda returns whenever the reader is nil, so without the guard a saved event whose creator
  # row had been destroyed would be handed to whoever validated it next. With it that write is a
  # harmless nil and the required association refuses the save, which is what such an event did
  # before this default existed.
  #
  # Both safe navigations earn their place: `group&.` because the callback runs ahead of the group
  # presence check, so `Event.new.valid?` would otherwise raise instead of collecting its errors,
  # and `members&.` because `nil&.members.find_by` raises on `find_by` rather than short-circuiting.
  belongs_to :creator, class_name: "Member", foreign_key: "creator_id", inverse_of: :created_events,
    default: -> { group&.members&.find_by(user: Current.user) if new_record? }
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
    self.tap do |event|
      event.starts_at += duration
      event.ends_at   += duration
    end
  end

  def duplicate
    self.dup.tap do |event|
      event.status = Event.new.status
    end
  end
end
