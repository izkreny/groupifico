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

  # An answer belongs to an event that can still take one, whoever is writing it. A domain
  # invariant rather than an authorization rule, and it lives here for the reason
  # `docs/AUTHORIZATION.md` gives for the last-active-owner guard: the tables decide who may act,
  # and "this event is over" is not a fact about the actor. Without it the screen's own guard was
  # the whole of the protection, and a posted answer to a concluded event still succeeded.
  #
  # Only an answer is checked. `reserved` and `invited` are what somebody filling the event writes,
  # and correcting a roster after the fact is their business rather than this rule's.
  validate :event_must_be_open_to_answers, if: -> { answered? && will_save_change_to_status? }

  # Whether this member has said anything, asked by the event card to choose between the question
  # and the answer it draws. The two unanswered statuses are not a "no": `reserved` is a place held
  # before anybody was asked and `invited` is a question still waiting.
  def answered?
    ANSWERS.include?(status)
  end

  private
    def event_must_be_open_to_answers
      errors.add(:status, "cannot be answered once the event is over") unless event&.open_to_answers?
    end
end
