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
    @registration = @event.registrations.new(registration_params)

    authorize! @registration

    if @registration.save
      redirect_to group_event_registration_path(@group, @event, @registration),
        notice: "Registration was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize! @registration

    if @registration.update(registration_params)
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

    def registration_params
      params.expect(registration: [ :status, :member_id ])
    end
end
