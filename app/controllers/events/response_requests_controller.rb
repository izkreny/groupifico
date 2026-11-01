# Asking every active member nobody has asked yet, from the roster's "Ask the rest" and the Next
# up card's "Ask everyone", which are one action. Both are the registering row, so both ask
# `RegistrationPolicy#create?` of a registration with no member on it, exactly as the roster does
# before drawing either button.
class Events::ResponseRequestsController < ApplicationController
  include GroupScoped

  before_action :set_event

  # WHY: back to where it was pressed, because the roster, the events list and the group home all
  # offer it; the event is the fallback for a request that names no page.
  def create
    authorize! Registration.new(event: @event), to: :create?

    redirect_back_or_to group_event_path(@group, @event), notice: asked_notice(@event.request_all_responses)
  end

  private
    def set_event
      @event = @group.events.find(params.expect(:event_id))
    end

    def asked_notice(count)
      count.zero? ? "Nobody was left to ask." : "#{helpers.pluralize(count, "member")} asked."
    end
end
