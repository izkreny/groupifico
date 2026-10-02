# A roster row's paper plane. The invitation row rather than `RegistrationsController#update`,
# because asking somebody is filling the event, which the event's manager may do and `update?`
# refuses them.
class Registrations::InvitationsController < ApplicationController
  include GroupScoped

  before_action :set_registration

  def create
    authorize! @registration, to: :create?

    name = @registration.member.full_name
    redirect_to group_event_path(@group, @registration.event),
      notice: @registration.invite ? "#{name} invited." : "#{name} was already asked."
  end

  private
    def set_registration
      @registration = @group.events.find(params.expect(:event_id)).registrations.find(params.expect(:registration_id))
    end
end
