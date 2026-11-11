# A roster row's paper plane. The registering row rather than `RegistrationsController#update`,
# because requesting a response is filling the event, which the event's manager may do and `update?`
# refuses them.
class Registrations::ResponseRequestsController < ApplicationController
  include EventScoped

  before_action :set_registration

  def create
    authorize! @registration, to: :create?

    member = @registration.member

    if member.active? && @event.open_to_answers?
      notice = "#{member.full_name}'s response was already requested." unless @registration.request_response
      redirect_back_or_to group_event_path(@group, @registration.event), status: :see_other, notice:
    elsif member.active?
      redirect_back_or_to group_event_path(@group, @registration.event), status: :see_other, alert: "This event is #{@event.status}, so no response was requested."
    else
      redirect_back_or_to group_event_path(@group, @registration.event), status: :see_other, alert: "#{member.full_name} is #{member.status}, so no response was requested."
    end
  end

  private
    def set_registration
      @registration = @event.registrations.find(params.expect(:registration_id))
    end
end
