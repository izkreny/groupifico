class RegistrationsController < ApplicationController
  include GroupScoped

  before_action :set_event
  before_action :set_registration

  # WHY: back to where the button was pressed, a row, a hero card or the event screen, so Turbo takes it as a refresh and the page morphs in place; the event is the fallback for a request that names no page of ours.
  def update
    authorize! @registration

    attributes = registration_params
    authorize! @registration, to: :manage_answers? unless Registration.answer?(attributes[:status])

    if @registration.update(attributes)
      redirect_back_or_to group_event_path(@group, @event), status: :see_other
    else
      # An answer is a button rather than a field, so there is no form to re-render and no typed
      # value to keep: the only way here is a posted status the enum refuses, which says what is
      # wrong on the screen the buttons live on.
      redirect_back_or_to group_event_path(@group, @event), alert: @registration.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    def set_event
      @event = @group.events.find(params.expect(:event_id))
    end

    def set_registration
      @registration = @event.registrations.find(params.expect(:id))
    end

    # Used on update: member_id stays out, so a registration cannot be handed to another member.
    # `update?` is decided against the record as loaded, so a permitted member_id would let a member
    # holding no role move their own registration onto somebody else and answer for them - two rows
    # the events table gives the three roles and the manager - and lose their own registration,
    # which `destroy?` refuses them. The same split, for the same reason, as `MembersController`
    # keeping user_id off update.
    def registration_params
      params.expect(registration: [ :status ])
    end
end
