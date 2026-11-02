# A roster row's paper plane. The registering row rather than `RegistrationsController#update`,
# because asking somebody is filling the event, which the event's manager may do and `update?`
# refuses them.
class Registrations::ResponseRequestsController < ApplicationController
  include EventScoped

  before_action :set_registration

  def create
    authorize! @registration, to: :create?

    member = @registration.member

    if member.active?
      notice = "#{member.full_name}'s response was already requested." unless @registration.request_response
      redirect_back_or_to group_event_path(@group, @registration.event), status: :see_other, notice:
    else
      redirect_back_or_to group_event_path(@group, @registration.event), status: :see_other, alert: "#{member.full_name} is #{member.status}, so no response was requested."
    end
  end

  private
    def set_registration
      @registration = @event.registrations.find(params.expect(:registration_id))
    end
end
