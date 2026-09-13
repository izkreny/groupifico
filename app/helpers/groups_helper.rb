module GroupsHelper
  NOTHING_SCHEDULED = "nothing scheduled".freeze
  HAPPENING_NOW     = "happening now".freeze

  # The index card's second fact: when this group next meets, that it is meeting right now, or that
  # it does not. A day and no clock time, because a card in a list states that there is something
  # on Tuesday and the screen behind it states at what hour - `EventsHelper` keeps the reading that
  # carries both private for the same reason.
  #
  # The running case needs its own words rather than a date: `Group#featured_event` answers with an
  # event already under way where there is one, and "next: Tue 2 Sep" about a day that has arrived
  # reads as a card that failed to refresh.
  def featured_event_line(group)
    event = group.featured_event

    return NOTHING_SCHEDULED unless event
    return HAPPENING_NOW     if event.ongoing?

    "next: #{event.starts_at.strftime(EventsHelper::DATE_FORMAT)}"
  end
end
