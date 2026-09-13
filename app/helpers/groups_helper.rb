module GroupsHelper
  # The segmented control's order is frame 2e's, not the enum's. The enum lists `general` first
  # because it is what `Brand` answers for an unbranded domain; the control reads better with the
  # two named types first and the catch-all last.
  SEGMENT_ORDER = %w[ choir band general ].freeze

  NOTHING_SCHEDULED = "nothing scheduled".freeze
  HAPPENING_NOW     = "happening now".freeze

  # The list itself, with no arithmetic for a type nobody has scheduled. A type added to `Group`
  # and not placed here would go unoffered by the only screen that sets the attribute, so the
  # helper spec asserts this list covers the enum: the miss fails the suite rather than the screen.
  def group_type_choices
    SEGMENT_ORDER.map { [ it.capitalize, it ] }
  end

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
