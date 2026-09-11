module GroupsHelper
  # The segmented control's order is frame 2e's, not the enum's. The enum lists `general` first
  # because it is what `Brand` answers for an unbranded domain; the control reads better with the
  # two named types first and the catch-all last.
  SEGMENT_ORDER = %w[ choir band general ].freeze

  NOTHING_SCHEDULED = "nothing scheduled".freeze

  # The list itself, with no arithmetic for a type nobody has scheduled. A type added to `Group`
  # and not placed here would go unoffered by the only screen that sets the attribute, so the
  # helper spec asserts this list covers the enum: the miss fails the suite rather than the screen.
  def group_type_choices
    SEGMENT_ORDER.map { [ it.capitalize, it ] }
  end

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
