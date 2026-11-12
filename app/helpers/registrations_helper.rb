module RegistrationsHelper
  # Who the list screen lists as off the list: current members with no registration on the event, tickable ones first and paused ones after, since a paused member is shown and cannot be ticked. `status` is an enum backed by its declaration order, `active` before `paused`, so ordering by the column is ordering by that rule rather than by an alphabetical accident.
  #
  # The profile is preloaded because `Member#full_name` delegates through `user`, and the screen
  # draws a name per row.
  def members_available(group, event)
    group.members.current.without_registration_for(event).preloaded.order(:status)
  end

  # The roster's line under its rows. Both numbers count active members alone: a paused member cannot be
  # added, so counting them would state a shortfall nobody can close, and an inactive one has
  # left the group entirely. Those of them still on the list are `not_active_on_list_line`'s.
  def list_tally(group, event)
    active = group.members.active

    "#{active.where(id: event.registrations.select(:member_id)).count} of #{active.count} active members are on the list."
  end

  # WHY: the rows the tally leaves out of its numbers, stated only while the list holds any, and naming only the kinds it holds.
  def not_active_on_list_line(event)
    counts = Member.where(id: event.registrations.select(:member_id)).where(status: %i[ paused inactive ]).group(:status).count
    parts = %w[ paused inactive ].filter_map { |status| "#{counts[status]} #{status}" if counts[status].to_i.positive? }
    total = counts.values.sum

    "#{parts.join(", and ")} #{total == 1 ? "member is" : "members are"} on the list too." if parts.any?
  end

  # What a roster row's badge says to a screen reader, and on hover. An answer is its own word; the
  # two unanswered statuses are not, because a bare "requested" and "reserved" read as facts about the
  # member rather than as where the question stands.
  def registration_status_label(registration)
    if registration.response_requested?
      "Response requested"
    elsif registration.reserved?
      "Place reserved, no response requested yet"
    else
      registration.status.capitalize
    end
  end
end
