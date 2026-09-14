class RegistrationsController < ApplicationController
  include GroupScoped

  # One message for every way a ticked member can stop being invitable while the reader was
  # choosing - registered by somebody else, paused, or gone from the group - and for both sides of
  # the write it can happen on. It names none of them, because the controller cannot tell which
  # happened and the reader's answer is the same either way: the list moved, here it is again.
  #
  # It says nobody rather than some, because that is what reaching it means: the set is empty, so
  # every ticked member was dropped. Which also makes it read the same for one tick and for ten.
  MOVED_ON = "Nobody was invited: nobody you ticked is still on the list. Here it is again.".freeze

  before_action :set_event
  before_action :set_registration, only: %i[ update destroy ]

  # The invitation screen. A registration nobody has been chosen for is nobody's, so `own?` is
  # false on it and `create?` is the three roles and the event's manager alone - the invitation row
  # of the events table, which is exactly who this screen is for.
  def new
    @registration = @event.registrations.new

    authorize! @registration
  end

  # One `invited` registration per ticked member. The status is written here rather than posted,
  # because this screen is the only thing that posts here and `invited` is the only thing it means,
  # so there is no posted status for a second question to ask about - which is why `create` asks
  # one rule where `update` asks two.
  #
  # Asked of the record with no member on it, which costs nothing now that `create?` no longer
  # reads one: an empty set is answered by the same call as a full one.
  def create
    @registration = @event.registrations.new

    authorize! @registration

    ticked  = member_ids
    invited = @event.invite(invitees(ticked))

    if invited.any?
      redirect_to group_event_path(@group, @event),
        notice: "#{helpers.pluralize(invited.size, "member")} invited."
    else
      # The two ways of inviting nobody read the same to the controller and differently to the
      # reader: one of them ticked somebody, and telling them to tick somebody sends them back to
      # re-tick the row that was taken out from under them.
      flash.now[:alert] = ticked.any? ? MOVED_ON : "Pick at least one member to invite."
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    # The same move as the intersection above, arriving too late for it: the row landed while this
    # request was writing rather than before it read. The transaction has rolled the whole set back,
    # so the answer is the same one - the screen again, redrawn without whoever moved.
    flash.now[:alert] = MOVED_ON
    render :new, status: :unprocessable_content
  end

  def update
    authorize! @registration

    attributes = registration_params
    authorize! @registration, to: :manage_answers? unless Registration.answer?(attributes[:status])

    if @registration.update(attributes)
      redirect_to group_event_path(@group, @event),
        notice: "Registration was successfully updated.",
        status: :see_other
    else
      # An answer is a button rather than a field, so there is no form to re-render and no typed
      # value to keep: the only way here is a posted status the enum refuses, which says what is
      # wrong on the screen the buttons live on.
      redirect_to group_event_path(@group, @event),
        alert: @registration.errors.full_messages.to_sentence,
        status: :see_other
    end
  end

  def destroy
    authorize! @registration

    @registration.destroy!

    redirect_to group_event_path(@group, @event),
      notice: "Registration was successfully destroyed.",
      status: :see_other
  end

  private
    def set_event
      @event = @group.events.find(params.expect(:event_id))
    end

    def set_registration
      @registration = @event.registrations.find(params.expect(:id))
    end

    # What the reader actually ticked, blanks dropped - the screen posts a hidden empty entry so the
    # key is always there. Read separately from the intersection below because an empty result means
    # different things depending on whether this was empty too.
    def member_ids
      params.expect(member_ids: []).compact_blank
    end

    # Those of them the screen would still offer, rather than the ids as posted. They are unscoped:
    # one naming somebody from another group would publish their name through `Event#attendees` to
    # people with no claim on it.
    #
    # It reads the set as it stands now, which closes the row that was registered while the form sat
    # open and not the one registered while this request runs - that one reaches the unique index,
    # and `create` rescues it.
    def invitees(ids)
      @group.members.active.without_registration_for(@event).where(id: ids)
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
