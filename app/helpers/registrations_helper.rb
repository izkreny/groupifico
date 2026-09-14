module RegistrationsHelper
  # Who the invitation screen lists: members with no registration on the event, `inactive` ones
  # excluded because they have left the group, tickable ones first and paused ones after, since a
  # paused member is shown and cannot be ticked. `status` is an enum backed by its declaration
  # order, `active` before `paused`, so ordering by the column is ordering by that rule rather
  # than by an alphabetical accident.
  #
  # The profile is preloaded because `Member#full_name` delegates through `user`, and the screen
  # draws a name per row.
  def members_available(group, event)
    group.members.without_registration_for(event).where.not(status: :inactive).includes(:profile).order(:status)
  end

  # The screen's header line. Both numbers count active members alone: a paused member cannot be
  # invited, so counting them would state a shortfall nobody can close, and an inactive one has
  # left the group entirely.
  def invited_tally(group, event)
    active = group.members.active

    "#{active.where(id: event.registrations.select(:member_id)).count} of #{active.count} invited"
  end
end
