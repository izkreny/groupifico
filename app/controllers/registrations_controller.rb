class RegistrationsController < ApplicationController
  before_action :set_group
  before_action :set_event
  before_action :set_registration, only: %i[ show edit update destroy ]

  def index
    authorize! @group, to: :show?

    @registrations = authorized_scope(@event.registrations)
  end

  def show
    authorize! @registration
  end

  def new
    @registration = @event.registrations.new

    authorize! @registration
  end

  def edit
    authorize! @registration
  end

  def create
    attributes    = new_registration_params
    @registration = @event.registrations.new(attributes)

    authorize! @registration
    authorize! @registration, to: :manage_answers? unless answering?(attributes[:status])

    if @registration.save
      redirect_to group_event_registration_path(@group, @event, @registration),
        notice: "Registration was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize! @registration

    attributes = registration_params
    authorize! @registration, to: :manage_answers? unless answering?(attributes[:status])

    if @registration.update(attributes)
      redirect_to group_event_registration_path(@group, @event, @registration),
        notice: "Registration was successfully updated.",
        status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! @registration

    @registration.destroy!

    redirect_to group_event_registrations_path(@group, @event),
      notice: "Registration was successfully destroyed.",
      status: :see_other
  end

  private
    def set_group
      @group = Group.find(params.expect(:group_id))
    end

    def set_event
      @event = @group.events.find(params.expect(:event_id))
    end

    def set_registration
      @registration = @event.registrations.find(params.expect(:id))
    end

    # Used on create: deciding whose registration it is is what creating one means. :member_id is
    # checked, not trusted. The form's picker offers members_available(group, event), which is this
    # group's, but the parameter is unscoped: registering somebody from another group publishes
    # their name through Event#attendees to people with no claim on it.
    def new_registration_params
      params.expect(registration: [ :status, :member_id ])
        .tap { |permitted| permitted.delete(:member_id) if foreign_member?(permitted[:member_id]) }
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
    # The posted value rather than the record's, on create as well as update. `reserved` is the
    # model's default, so a member registering themselves without naming a status has claimed
    # nothing, and reading the record instead would refuse the commonest case there is.
    def answering?(status)
      status.nil? || status.in?(Registration::ANSWERS)
    end

    # Present and not ours. A blank passes through so the model refuses it, rather than being
    # dropped here and turning an invalid submission into a silent no-change.
    def foreign_member?(id)
      id.present? && !@group.members.exists?(id)
    end
end
