module EventsHelper
  DATETIME_FORMAT = "%Y-%m-%d %H:%M"
  TIME_FORMAT     = "%H:%M"
  SEPARATOR       = " – "

  # TODO: Localize and translate using l() and time zones
  def event_schedule(event)
    event.starts_at.strftime(DATETIME_FORMAT) +
    SEPARATOR +
    event.ends_at.strftime(event.same_day? ? TIME_FORMAT : DATETIME_FORMAT)
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
