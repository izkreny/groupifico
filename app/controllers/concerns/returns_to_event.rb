# Where a registration's buttons land: back on the event screen exactly as it was, query string and all, when that is where the button was pressed, and on the event otherwise.
#
# The exact URL is the point. Turbo takes a redirect to the page it came from as a refresh, which the event screen morphs in place, keeping the scroll and the roster's fold; any other URL is a new visit that redraws the page from the top.
module ReturnsToEvent
  extend ActiveSupport::Concern

  private
    def redirect_to_event(event, **)
      screen = group_event_path(event.group, event)
      back = url_from(request.referer)
      back = screen unless back && URI(back).path == screen

      redirect_to back, status: :see_other, **
    end
end
