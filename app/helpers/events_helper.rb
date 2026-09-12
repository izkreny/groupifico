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
      "#{day_and_time(event.starts_at)}#{RANGE}#{event.ends_at.strftime(TIME_FORMAT)}"
    else
      "#{day_and_time(event.starts_at)}#{SEPARATOR}#{day_and_time(event.ends_at)}"
    end
  end

  def event_schedule_start(event)
    day_and_time(event.starts_at)
  end

  # The hero card's first line, which has two readings because the card now draws an event that has
  # already begun. The countdown is `time_ago_in_words`, which measures a distance and never a
  # direction, so pointing it at `starts_at` once the event has started counts the wrong way; while
  # it runs, the distance worth stating is the one to the end.
  def event_kicker(event)
    if event.ongoing?
      "Happening now#{DOT}ends in #{time_ago_in_words event.ends_at}"
    else
      "Next up#{DOT}in #{time_ago_in_words event.starts_at}"
    end
  end

  # Status and category on one line, the way every hero card and detail screen draws them. The
  # category is folded in rather than tagged separately, and `other` is the category that says
  # nothing, so it leaves the status standing alone.
  def event_status_line(event)
    [ event.status.capitalize, (event.category unless event.other?) ].compact.join(" ")
  end

  # Who has said yes, for the hero card's one line of names. Queried with the names preloaded
  # rather than read off the loaded registrations: the hero is fetched by `Group#next_event`, which
  # no screen's preload reaches, and `Member` gets its name through `user` - so selecting in memory
  # walked two queries per answer.
  def said_yes_line(event)
    names = event.registrations.yes.includes(member: :profile).map { it.member.full_name }

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

  private
    # The day and the clock time of one instant, which is a whole reading on a compact row and
    # half of one in a range. Private because no view states an instant: a view states an event,
    # and which end of it the two readings above decide.
    def day_and_time(at)
      "#{at.strftime(DATE_FORMAT)}#{DOT}#{at.strftime(TIME_FORMAT)}"
    end
end
