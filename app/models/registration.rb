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

  # The statuses that are an answer. `reserved` and `response_requested` are the other two, and they are what
  # somebody filling the event puts you into rather than something you say about yourself. Named
  # here because the vocabulary is the model's; `RegistrationPolicy` and `RegistrationsController`
  # both read it rather than each holding a list.
  ANSWERS = %w[ yes maybe no ].freeze

  enum :status, %i[ reserved response_requested yes maybe no ], default: :reserved, validate: true

  scope :preloaded, -> { includes(member: :profile) }

  # An answer belongs to an event that can still take one, whoever is writing it. A domain
  # invariant rather than an authorization rule, and it lives here for the reason
  # `docs/AUTHORIZATION.md` gives for the last-active-owner guard: the tables decide who may act,
  # and "this event is over" is not a fact about the actor. Without it the screen's own guard was
  # the whole of the protection, and a posted answer to a concluded event still succeeded.
  #
  # Only an answer is checked. `reserved` and `response_requested` are what somebody filling the event writes,
  # and correcting a roster after the fact is their business rather than this rule's.
  validate :event_must_be_open_to_answers, if: -> { answered? && will_save_change_to_status? }

  # WHY: the screens offer `Event#available_registration_answers` and this holds a stale form to the same list. It stays quiet where the rule above already refuses, so a concluded event gives one reason, not two.
  validate :answer_must_be_one_the_event_takes, if: -> { answered? && will_save_change_to_status? && event&.open_to_answers? }

  # Whether a status somebody posted is one they are saying about themselves, which no record can
  # answer because a posted status is not on the record yet. A blank counts: `reserved` is the
  # model's default, so somebody answering without naming a status has claimed nothing.
  #
  # The vocabulary is this model's, so the question is too - `RegistrationsController` reads it
  # rather than holding a second copy of `ANSWERS`.
  def self.answer?(status)
    status.nil? || ANSWERS.include?(status)
  end

  # WHY: whether this member has said anything, which the event card shows as their answer. It is a separate question from `response_due?`, because once an event has ended a `maybe` is both answered and due again. The two unanswered statuses are not a "no": `reserved` is a place held before any response was requested and `response_requested` is a question still waiting.
  def answered?
    ANSWERS.include?(status)
  end

  # WHY: whether the answer row puts the question to this member rather than showing their answer. Before the event ends that is a question still waiting, and a held place has none due. Once it has ended it is anyone whose attendance is still unknown: a held place, a question nobody answered, and a `maybe`, none of which `Event#available_registration_answers` offers any more.
  def response_due?
    event.ended? ? event.available_registration_answers.exclude?(status) : response_requested?
  end

  # WHY: the one rule for requesting a response, read by the roster row's paper plane and by `Event#request_all_responses` alike. Both are reachable by anyone the registering row admits, the event's manager included, who may not overrule an answer; so only a held place moves, and only an active member's, since a paused or inactive one never gets a request. Only on an event still open to answers, too, because a concluded or canceled one refuses the answer the request asks for. Whether it moved is the return value.
  #
  # WHY: the email goes from here rather than from a callback on the status, because `RegistrationsController#update` lets a manager post `response_requested` onto any row, a paused member's included. It waits for the outermost commit, because `deliver_later` enqueues at once into a queue database that a rollback here never reaches.
  def request_response
    if reserved? && member.active? && event.open_to_answers? && response_requested!
      ActiveRecord.after_all_transactions_commit { RegistrationMailer.response_requested(self).deliver_later }
      true
    else
      false
    end
  end

  private
    def event_must_be_open_to_answers
      errors.add(:base, "This event is concluded or canceled, so it no longer takes replies.") unless event&.open_to_answers?
    end

    def answer_must_be_one_the_event_takes
      errors.add(:base, "This event has ended, so it is a yes or a no.") unless event.available_registration_answers.include?(status)
    end
end
