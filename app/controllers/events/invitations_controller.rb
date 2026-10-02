# Asking the whole list at once, from the roster's "Invite the rest" and the Next up card's "Invite
# everyone". Both are the invitation row, so both ask `RegistrationPolicy#create?` of a registration
# with no member on it, exactly as the roster does before drawing either button.
class Events::InvitationsController < ApplicationController
  include GroupScoped

  before_action :set_event

  def create
    authorize! Registration.new(event: @event), to: :create?

    redirect_to group_event_path(@group, @event), notice: invited_notice(@event.invite_all_active_members)
  end

  def update
    authorize! Registration.new(event: @event), to: :create?

    redirect_to group_events_path(@group), notice: invited_notice(@event.invite_reserved), status: :see_other
  end

  private
    def set_event
      @event = @group.events.find(params.expect(:event_id))
    end

    def invited_notice(count)
      count.zero? ? "Nobody was left to invite." : "#{helpers.pluralize(count, "member")} invited."
    end
end
