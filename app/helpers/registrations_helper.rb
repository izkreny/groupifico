module RegistrationsHelper
  # Who the invitation screen lists: the group's members with no registration on this event, never
  # invited or taken off. `inactive` is excluded outright, because they have left; `paused` members
  # are listed and cannot be ticked, which is the frame's own rule, so the order puts the tickable
  # ones first. `status` is an enum backed by the declaration order, `active` before `paused`, so
  # ordering by the column is ordering by that rule rather than by an alphabetical accident.
  #
  # The profile is preloaded because `Member#full_name` delegates through `user`, and the screen
  # draws a name per row.
  def members_available(group, event)
    group.members
      .where.not(id: event.registrations.select(:member_id))
      .where.not(status: :inactive)
      .includes(:profile)
      .order(:status)
  end

  # The screen's header line. Both numbers count active members alone: a paused member cannot be
  # invited, so counting them would state a shortfall nobody can close, and an inactive one has
  # left the group entirely.
  def invited_tally(group, event)
    active = group.members.active

    "#{active.where(id: event.registrations.select(:member_id)).count} of #{active.count} invited"
  end
end
