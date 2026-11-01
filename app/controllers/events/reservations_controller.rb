# Holding a place for every active member off the list, from the roster's "Reserve a place for everyone". It asks nobody. It is the registering row, so it asks `RegistrationPolicy#create?` of a registration with no member on it, exactly as the roster does before drawing the button.
class Events::ReservationsController < ApplicationController
  include GroupScoped

  before_action :set_event

  def create
    authorize! Registration.new(event: @event), to: :create?

    redirect_back_or_to group_event_path(@group, @event), notice: reserved_notice(@event.reserve_all_active_members)
  end

  private
    def set_event
      @event = @group.events.find(params.expect(:event_id))
    end

    def reserved_notice(count)
      count.zero? ? "Nobody was left to add." : "#{helpers.pluralize(count, "place")} reserved."
    end
end
