module EventsHelper
  DATETIME_FORMAT = "%Y-%m-%d %H:%M"
  DATE_FORMAT     = "%a %-d %b"
  TIME_FORMAT     = "%H:%M"
  SEPARATOR       = " – "
  RANGE           = "–"
  DOT             = " · "

  # TODO: Localize and translate using l() and time zones
  def event_schedule(event)
    event.starts_at.strftime(DATETIME_FORMAT) +
    SEPARATOR +
    event.ends_at.strftime(event.same_day? ? TIME_FORMAT : DATETIME_FORMAT)
  end

  # The card's own two readings of the same schedule: the range a hero card and the detail screen
  # carry, and the start alone that a compact row carries beside the place. Both print in
  # `Time.zone`, which `starts_at` already answers in.
  def event_schedule_range(event)
    if event.same_day?
      "#{event_schedule_start(event)}#{RANGE}#{event.ends_at.strftime(TIME_FORMAT)}"
    else
      "#{event_schedule_start(event)}#{SEPARATOR}#{event_schedule_start(event, event.ends_at)}"
    end
  end

  def event_schedule_start(event, at = event.starts_at)
    "#{at.strftime(DATE_FORMAT)}#{DOT}#{at.strftime(TIME_FORMAT)}"
  end

  # Status and category on one line, the way every hero card and detail screen draws them. The
  # category is folded in rather than tagged separately, and `other` is the category that says
  # nothing, so it leaves the status standing alone.
  def event_status_line(event)
    [ event.status.capitalize, (event.category unless event.other?) ].compact.join(" ")
  end

  # Who has said yes, for the hero card's one line of names. Read from the loaded registrations
  # rather than queried, so the card costs nothing beyond the preload the screen already does.
  def said_yes_line(event)
    names = event.registrations.select(&:yes?).map { it.member.full_name }

    "#{names.to_sentence} said yes" if names.any?
  end

  # TODO: Translate statuses and categories, something like:
  #       `Event.status.map { |status| 18n.t(status, scope: "statuses") }`
  def event_statuses
    Event.statuses.keys.map { [ it.upcase, it ] }
  end

  def event_categories
    Event.categories.keys
  end
end
