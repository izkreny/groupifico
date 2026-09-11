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

  # The acting membership, asked once. `Current.member` is the application's answer to "which
  # member is acting in this group", so this reads it rather than deriving a second answer from the
  # event's own group - a route change, not a result change: every controller that creates an event
  # is nested under the group it is created in, and `GroupScoped` sets `Current.group` from that
  # same segment of the URL.
  #
  # Outside a request there is no acting member and the lambda answers nil, which the required
  # association then refuses. That is the console, the job and `db/seeds.rb`, and each of them
  # already names its creator: an event nobody created is a record with no author, not a default
  # worth guessing.
  #
  # `new_record?` keeps it a create-time fill. The callback is unconditional and writes whatever
  # the lambda returns whenever the reader is nil, so without the guard a saved event whose creator
  # row had been destroyed would be handed to whoever validated it next. With it that write is a
  # harmless nil and the required association refuses the save, which is what such an event did
  # before this default existed.
  belongs_to :creator, class_name: "Member", foreign_key: "creator_id", inverse_of: :created_events,
    default: -> { Current.member if new_record? }
  belongs_to :manager, class_name: "Member", foreign_key: "manager_id", inverse_of: :managed_events, optional: true
  has_many :registrations, dependent: :destroy
  has_many :attendees, through: :registrations, source: :member

  enum :status, %i[ unconfirmed confirmed concluded canceled ], default: :unconfirmed, validate: true
  enum :category, %i[ other rehearsal gig ], default: :other, validate: true

  validates_associated :address, :manager

  # The guarantee the `Current.member` default gave up. Deriving the creator from the event's own
  # group made a cross-group creator structurally impossible; reading it from `Current` moves that
  # to the caller's discipline, and the database says nothing at all - `events.creator_id` carries
  # no foreign key, only `address_id` and `group_id` do. So the model states the rule itself, the
  # way `EventsController#event_params` already states it for `manager_id` and `address_id`.
  #
  # `allow_nil` leaves the absent case to `belongs_to`, which already answers "must exist"; without
  # it an event created outside a request collects that error twice under two different wordings.
  # The lambda takes the record because Rails calls an `inclusion` delimiter with it - a zero-arity
  # one raises `ArgumentError` - and `group&.` because the callback runs ahead of the group
  # presence check. The fallback is what stops `group&.members` answering nil and the validator
  # sending `include?` to it; `Member.none` rather than `[]` only because it keeps the expression
  # one relation throughout, both being empty and neither raising.
  validates :creator, inclusion: { in: ->(event) { event.group&.members || Member.none } }, allow_nil: true

  validates :name, :starts_at, presence: true
  validates :name, length: { maximum: 250 }
  validates :description, length: { maximum: 25_000 }
  validates :ends_at, comparison: { greater_than: :starts_at }

  scope :upcoming, -> { where(starts_at: Time.now..) }
  scope :ongoing,  -> { where(starts_at: ...Time.now).where(ends_at: Time.now..) }
  scope :past,     -> { where(ends_at: ...Time.now) }

  # The tallies the event card draws, in one query, with a zero for a status nobody holds so the
  # card draws the same four tags whatever the answers are. `reserved` is not among them: a place
  # held that nobody has been asked about is the absence of an answer rather than one, and it is
  # the one status the card never counts. `invited` is what the card labels "no reply".
  def answer_counts
    tallies = registrations.group(:status).count

    (Registration.statuses.keys - [ "reserved" ]).index_with { tallies.fetch(it, 0) }
  end

  # Which registration belongs to the reader, read from the loaded association rather than queried,
  # so a list that preloads `registrations` answers it for every row without a query per row. A
  # caller with no acting member gets nil, because `registrations.member_id` is `NOT NULL` and so
  # matches nothing.
  def registration_for(member)
    registrations.find { it.member_id == member&.id }
  end

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
