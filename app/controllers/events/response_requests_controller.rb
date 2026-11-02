# Requesting a response from every active member holding a place, from the roster's "Request the rest" and the Next up card's "Request responses", which are one action. Both are the registering row, so both check `RegistrationPolicy#create?` against a registration with no member on it, exactly as the roster does before drawing either button.
class Events::ResponseRequestsController < ApplicationController
  include EventScoped

  # WHY: back to where it was pressed, because the roster, the events list and the group home all
  # offer it; the event is the fallback for a request that names no page.
  def create
    authorize! Registration.new(event: @event), to: :create?

    redirect_back_or_to group_event_path(@group, @event), notice: requested_notice(@event.request_all_responses)
  end

  private
    def requested_notice(count)
      count.zero? ? "Nobody was left to request a response from." : "#{helpers.pluralize(count, "response")} requested."
    end
end
