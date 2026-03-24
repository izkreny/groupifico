module EventsHelper
  DATETIME_FORMAT = "%Y-%m-%d %H:%M"
  TIME_FORMAT     = "%H:%M"
  SEPARATOR       = " – "

  # TODO: Localize and translate using l() and time zones
  def event_schedule(event)
    event.starts_at.strftime(DATETIME_FORMAT) +
    SEPARATOR +
    event.ends_at.strftime(event.starts_at.to_date == event.ends_at.to_date ? TIME_FORMAT : DATETIME_FORMAT)
  end
end
