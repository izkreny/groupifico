# A roster row's paper plane. The invitation row rather than `RegistrationsController#update`,
# because asking somebody is filling the event, which the event's manager may do and `update?`
# refuses them.
class Registrations::InvitationsController < ApplicationController
  include GroupScoped

  before_action :set_registration

  def create
    authorize! @registration, to: :create?

    member = @registration.member

    if member.active?
      redirect_to group_event_path(@group, @registration.event),
        notice: @registration.invite ? "#{member.full_name} invited." : "#{member.full_name} was already asked."
    else
      redirect_to group_event_path(@group, @registration.event),
        alert: "#{member.full_name} is #{member.status}, so they are not asked."
    end
  end

  private
    def set_registration
      @registration = @group.events.find(params.expect(:event_id)).registrations.find(params.expect(:registration_id))
    end
end
