module GroupsHelper
  NOTHING_SCHEDULED = "nothing scheduled".freeze

  # The index card's second fact: when this group next meets, or that it does not. A day and no
  # clock time, because a card in a list states that there is something on Tuesday and the screen
  # behind it states at what hour - `EventsHelper` keeps the reading that carries both private for
  # the same reason.
  def next_event_line(group)
    event = group.next_event

    return NOTHING_SCHEDULED unless event

    "next: #{event.starts_at.strftime(EventsHelper::DATE_FORMAT)}"
  end
end
