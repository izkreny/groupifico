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
      if @registration.request_response_again
        notice = "#{member.full_name}'s response was requested again."
      elsif !@registration.request_response
        alert = "#{member.full_name} has already answered, so no response was requested."
      end
      redirect_back_or_to group_event_path(@group, @registration.event), status: :see_other, notice:, alert:
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
