class EventsController < ApplicationController
  before_action :set_group
  before_action :set_event, only: %i[ show edit update destroy ]

  # GET /events
  def index
    @events = @group.events
  end

  # GET /events/1
  def show
  end

  # GET /events/new
  def new
    @event         = @group.events.new
    @event.address = Address.new
  end

  # GET /events/1/edit
  def edit
    @event.address = Address.new unless @event.address
  end

  # POST /events
  def create
    @event = @group.events.new(event_params)

    if @event.save
      redirect_to [ @group, @event ], notice: "Event was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /events/1
  def update
    if @event.update(event_params)
      redirect_to group_event_path, notice: "Event was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /events/1
  def destroy
    @event.destroy!

    redirect_to group_events_path, notice: "Event was successfully destroyed.", status: :see_other
  end

  private
    def set_group
      @group = Group.find(params.expect(:group_id))
    end

    def set_event
      @event = @group.events.find(params.expect(:id))
    end

    def event_params
      params.expect(
        event: [ :name, :description, :starts_at, :ends_at, :status, :category, :group_id, :creator_id, :manager_id,
          address_attributes: [
            :id, :name, :street_name, :building_number, :city, :postal_code, :state_code, :country_code, :latitude, :longitude
          ]
        ]
      )
    end
end
