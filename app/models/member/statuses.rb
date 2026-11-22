module Member::Statuses
  extend ActiveSupport::Concern

  included do
    # WHY: each value names its stored integer, so the declaration can read in lifecycle order while the integers already in the column keep their meaning. `order(:status)` still sorts by those integers, `active` before `paused`.
    enum :status, { pending: 3, active: 0, paused: 1, inactive: 2 }, default: :active, validate: true

    # The members who belong to their group: `inactive` has left and `pending` has not been let in yet, so neither is one of the group's people nor reaches anything of it. One spelling, because the user's groups, the group's member count and the event list form all ask it, and a status added later has one place to be counted in or out.
    scope :current, -> { where(status: %i[ active paused ]) }

    # WHY: `pending` is where an invitation starts and nothing else, so no update moves a member into it. A member with registrations set back to pending would keep their places on rosters every member reads, which is the one thing a pending member must never be seen on.
    validate :not_moved_into_pending, on: :update
  end

  private
    def not_moved_into_pending
      errors.add(:status, "cannot be changed to pending") if status_changed? && pending?
    end
end
