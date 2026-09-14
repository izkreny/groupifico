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

  # What a roster row's badge says to a screen reader, and on hover. An answer is its own word; the
  # two unanswered statuses are not, because "invited" and "reserved" read as facts about the
  # member rather than as where the question stands.
  def registration_status_label(registration)
    if registration.invited?
      "Invited, no reply yet"
    elsif registration.reserved?
      "Place reserved, not asked yet"
    else
      registration.status.capitalize
    end
  end

  # The event roster's line above its rows, naming whoever the tally leaves out for being paused: a
  # paused member cannot be invited, so without the line they are missing from both the numbers
  # and the rows with nothing saying why. One who is already registered has a row of their own.
  def left_out_line(group, event)
    names = group.members.paused.without_registration_for(event).includes(:profile).map(&:full_name).sort_by(&:downcase)

    "#{names.to_sentence} #{names.one? ? "is" : "are"} paused, left out" if names.any?
  end
end
