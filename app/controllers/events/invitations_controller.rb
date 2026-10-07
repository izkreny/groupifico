# Asking every active member nobody has asked yet, from the roster's "Invite the rest" and the Next
# up card's "Invite everyone", which are one action. Both are the invitation row, so both ask
# `RegistrationPolicy#create?` of a registration with no member on it, exactly as the roster does
# before drawing either button.
class Events::InvitationsController < ApplicationController
  include GroupScoped

  before_action :set_event

  # WHY: back to where it was pressed, because the roster, the events list and the group home all
  # offer it; the event is the fallback for a request that names no page.
  def create
    authorize! Registration.new(event: @event), to: :create?

    redirect_back_or_to group_event_path(@group, @event), notice: invited_notice(@event.invite_all_active_members)
  rescue ActiveRecord::RecordNotUnique
    # WHY: somebody registered a member while this request was inviting; the transaction rolled the
    # whole set back, so nobody was invited and pressing again finishes the job.
    redirect_back_or_to group_event_path(@group, @event), alert: "Nobody was invited: the list changed while inviting. Try again."
  end

  private
    def set_event
      @event = @group.events.find(params.expect(:event_id))
    end

    def invited_notice(count)
      count.zero? ? "Nobody was left to invite." : "#{helpers.pluralize(count, "member")} invited."
    end
end
