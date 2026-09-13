class RegistrationsController < ApplicationController
  include GroupScoped

  before_action :set_event
  before_action :set_registration, only: %i[ update destroy ]

  def index
    authorize! @group, to: :show?

    @registrations = authorized_scope(@event.registrations)
  end

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

    invited = invite(invitees)

    if invited.any?
      redirect_to group_event_path(@group, @event),
        notice: "#{helpers.pluralize(invited.size, "member")} invited."
    else
      flash.now[:alert] = "Pick at least one member to invite."
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    # Somebody else invited one of the ticked members between `invitees` reading the set and the
    # write reaching the unique index. The transaction has rolled the whole set back, so the answer
    # is the screen again, redrawn without whoever arrived in the meantime.
    flash.now[:alert] = "Somebody was invited while you were choosing. Here is the list again."
    render :new, status: :unprocessable_content
  end

  def update
    authorize! @registration

    attributes = registration_params
    authorize! @registration, to: :manage_answers? unless answering?(attributes[:status])

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

    # The ticked members, intersected with the set the screen actually offered rather than trusted.
    # The ids are unscoped: one naming somebody from another group would publish their name through
    # `Event#attendees` to people with no claim on it. The screen's own hidden blank entry is
    # dropped by the same `where`.
    #
    # It reads the set as it stands now, which closes the row that was registered while the form
    # sat open and not the one registered while this request runs - that one reaches the unique
    # index, and `create` rescues it.
    def invitees
      @group.members.active.without_registration_for(@event).where(id: params.expect(member_ids: []))
    end

    # All or nothing: a set that is refused part way through leaves no half-filled event behind.
    def invite(members)
      Registration.transaction do
        members.map { @event.registrations.create!(member: it, status: :invited) }
      end
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

    # A posted status the actor is saying about themselves. `reserved` and `invited` are not
    # answers, so writing either is the second question `manage_answers?` decides.
    #
    # The posted value rather than the record's. `reserved` is the model's default, so a member
    # answering without naming a status has claimed nothing, and reading the record instead would
    # refuse the commonest case there is.
    def answering?(status)
      status.nil? || status.in?(Registration::ANSWERS)
    end
end
