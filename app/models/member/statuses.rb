module Member::Statuses
  extend ActiveSupport::Concern

  # WHY: a lambda rather than the attribute's current value, which a second change on the same record would inherit from the first; the first change and any later one given no date both start today, spelled once.
  STARTS_TODAY = -> { Date.current }

  included do
    # WHY: each value names its stored integer, so the declaration can read in lifecycle order while the integers already in the column keep their meaning. `order(:status)` still sorts by those integers, `active` before `paused`.
    enum :status, { pending: 3, active: 0, paused: 1, inactive: 2 }, default: :active, validate: true

    # The members who belong to their group: `inactive` has left and `pending` has not been let in yet, so neither is one of the group's people nor reaches anything of it. One spelling, because the user's groups, the group's member count and the event list form all ask it, and a status added later has one place to be counted in or out.
    scope :current, -> { where(status: %i[ active paused ]) }

    has_many :status_changes

    # The day the next change starts on and who makes it, read by the audit trail for the first change and every later one alike, so the start date's refusals land on the form's own field.
    attribute :status_starts_on, :date, default: STARTS_TODAY
    attr_writer :status_updater

    # WHY: states by name beside the enum and never with `value:`, which breaks creation, per ADR 0008; the enum keeps the integers.
    state_machine :status do
      state :pending, :active, :paused, :inactive

      event :join do
        transition pending: :active
      end

      event :pause do
        transition %i[ active inactive ] => :paused
      end

      event :deactivate do
        transition %i[ active paused ] => :inactive
      end

      event :activate do
        transition %i[ paused inactive ] => :active
      end

      audit_trail class: Member::StatusChange, context: %i[ status_starts_on status_updater ], if: :starts_a_new_day?

      before_transition do: :find_the_days_change
      after_transition  do: :fold_into_the_days_change

      # WHY: before the save rather than after it, inside the transition's transaction, per ADR 0008, so a change a validation refuses rolls the removal back with it.
      before_transition from: :active, to: %i[ paused inactive ], do: :remove_registrations_from_the_start_date
    end

    # WHY: `pending` is where an invitation starts and nothing else, so no update moves a member into it. A member with registrations set back to pending would keep their places on rosters every member reads, which is the one thing a pending member must never be seen on.
    validate :not_moved_into_pending, on: :update
    validate :status_starts_on_in_order, on: :update, if: :status_changed?
  end

  # The one way a status moves: the event that reaches `to` from the current status, fired with the day it starts on and who made it. The same status fires nothing and records nothing.
  def change_status(to, starts_on: STARTS_TODAY.call, updater: Current.member)
    return true if to.to_s == status

    self.status_starts_on = starts_on
    self.status_updater   = updater

    if (event = status_transitions(to: to.to_s.to_sym).first&.event)
      fire_status_event(event)
    else
      errors.add(:status, :inclusion)
      false
    end
  end

  def status_updater
    @status_updater || Current.member
  end

  private
    def not_moved_into_pending
      errors.add(:status, "cannot be changed to pending") if status_changed? && pending?
    end

    def status_starts_on_in_order
      latest = latest_status_change

      if status_starts_on.blank?
        errors.add(:status_starts_on, :blank)
      elsif status_starts_on.future?
        errors.add(:status_starts_on, "cannot be after today")
      elsif latest && status_starts_on < latest.starts_on
        errors.add(:status_starts_on, "cannot be before #{latest.starts_on.strftime("%-d %b %Y")}, when the current status started")
      end
    end

    # A change on a day that already has one takes that row over rather than adding a second, so the audit trail writes a row only for a day that has none. Read before the transition, since the audit trail's own row is on the day by the time it runs.
    def find_the_days_change
      @days_change = status_changes.find_by(starts_on: status_starts_on)
    end

    def starts_a_new_day?
      @days_change.nil?
    end

    # The day's change takes the new status and updater, unless that repeats the change before it, which then stands alone, so two neighbours never share a status.
    def fold_into_the_days_change
      return unless @days_change

      previous = status_changes.where(starts_on: ...status_starts_on).order(:starts_on).last

      if previous&.status == status
        @days_change.destroy!
      else
        @days_change.update!(status:, updater: status_updater)
      end
    end

    def latest_status_change
      status_changes.order(:starts_on).last
    end

    # WHY: an answer on an event that has ended stays, since it may be the record that the member was there, and a concluded or canceled event is never touched, per ADR 0008.
    #
    # WHY: a blank start date removes nothing and leaves the refusal to `status_starts_on_in_order`, which runs after this callback and puts it on the form's field.
    def remove_registrations_from_the_start_date
      return if status_starts_on.blank?

      from_the_start = registrations.joins(:event).where(events: { status: Event::OPEN_TO_ANSWERS, ends_at: status_starts_on.beginning_of_day.. })
      from_the_start.where(events: { ends_at: Time.current.. }).or(from_the_start.where.not(status: Registration::ANSWERS)).destroy_all
    end
end
