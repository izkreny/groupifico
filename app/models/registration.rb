# ## Schema Information
#
# Table name: `registrations`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`status`**      | `integer`          | `not null`
# **`created_at`**  | `datetime`         | `not null`
# **`updated_at`**  | `datetime`         | `not null`
# **`event_id`**    | `integer`          | `not null`
# **`member_id`**   | `integer`          | `not null`
#
# ### Indexes
#
# * `index_registrations_on_event_id`:
#     * **`event_id`**
# * `index_registrations_on_member_id`:
#     * **`member_id`**
# * `index_registrations_on_member_id_and_event_id` (_unique_):
#     * **`member_id`**
#     * **`event_id`**
#
# ### Foreign Keys
#
# * `event_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`event_id => events.id`**
# * `member_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`member_id => members.id`**
#
class Registration < ApplicationRecord
  belongs_to :member
  belongs_to :event

  # The statuses that are an answer. `reserved` and `invited` are the other two, and they are what
  # somebody filling the event puts you into rather than something you say about yourself. Named
  # here because the vocabulary is the model's; `RegistrationPolicy` and `RegistrationsController`
  # both ask it rather than each holding a list.
  ANSWERS = %w[ yes maybe no ].freeze

  enum :status, %i[ reserved invited yes maybe no ], default: :reserved, validate: true

  # Whether a status somebody posted is one they are saying about themselves, which no record can
  # answer because a posted status is not on the record yet. A blank counts: `reserved` is the
  # model's default, so somebody answering without naming a status has claimed nothing.
  #
  # The vocabulary is this model's, so the question is too - `RegistrationsController` asks it
  # rather than holding a second copy of `ANSWERS`.
  def self.answer?(status)
    status.nil? || ANSWERS.include?(status)
  end

  # Whether this member has said anything, asked by the event card to choose between the question
  # and the answer it draws. The two unanswered statuses are not a "no": `reserved` is a place held
  # before anybody was asked and `invited` is a question still waiting.
  def answered?
    ANSWERS.include?(status)
  end
end
