class EventsController < ApplicationController
  before_action :set_group
  before_action :set_event, only: %i[ show duplicate edit update destroy ]

  def index
    authorize! @group, to: :show?

    @events = authorized_scope(@group.events) # TODO: upcoming, past, ongoing, with filters
  end

  def show
    authorize! @event
  end

  def new
    @event = @group.events.new
    @event.build_address

    authorize! @event
  end

  # Authorizes create?, not show?: what this action reads is incidental, what it offers is a form
  # for making a new event. `new` resolves new? through create?, so authorizing show? here made two
  # doors onto the same form disagree - a paused member was refused at one and admitted at the other.
  def duplicate
    authorize! @event, to: :create?

    @event = @event.duplicate.shift_by(7.days)
    @event.build_address unless @event.address

    render :new
  end

  def edit
    @event.build_address unless @event.address

    authorize! @event
  end

  def create
    @event = @group.events.new(event_params)

    authorize! @event

    if @event.save
      redirect_to group_event_path(@group, @event),
        notice: "Event was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize! @event

    if @event.update(event_params)
      redirect_to group_event_path(@group, @event),
        notice: "Event was successfully updated.",
        status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! @event

    @event.destroy!

    redirect_to group_events_path(@group),
      notice: "Event was successfully destroyed.",
      status: :see_other
  end

  private
    def set_group
      @group = Group.find(params.expect(:group_id))
    end

    def set_event
      @event = @group.events.find(params.expect(:id))
    end

    # Three foreign keys the form submits, all checked rather than trusted. Each picker is already
    # scoped to this group - `group.members` twice, `group.addresses` once - but the parameters are
    # not, and an unscoped foreign key in the body is the same boundary-crossing the unscoped lookup
    # was, arriving by another door. `:address_id` is the one with teeth: pointing an event at
    # another group's address makes that address `reachable?`, and therefore editable, by somebody
    # with no claim on it. `:group_id` left in the earlier round and does not come back - the URL
    # supplies it.
    def event_params
      params.expect(
        event: [ :name, :description, :starts_at, :ends_at, :status, :category,
          :creator_id, :manager_id, :address_id,
          address_attributes: [
            :id, :name, :street_name, :building_number, :city, :postal_code, :state_code, :country_code, :latitude, :longitude
          ]
        ]
      ).tap do |permitted|
        permitted.delete(:creator_id) if foreign_member?(permitted[:creator_id])
        permitted.delete(:manager_id) if foreign_member?(permitted[:manager_id])
        permitted.delete(:address_id) if foreign_address?(permitted[:address_id])
      end
    end

    # Present and not ours. A blank passes straight through so the model decides what it means:
    # `creator` is required and refuses, `manager` is optional and is cleared. Dropping blanks here
    # instead would silently turn "remove the manager" into "leave it alone", and an invalid create
    # into a redirect.
    def foreign_member?(id)
      id.present? && !@group.members.exists?(id)
    end

    # `Group#addresses` unions the group's own address with its events', so it answers an Array as
    # often as a relation - `exists?` is not available on it, and `none?` with a block works for both.
    def foreign_address?(id)
      id.present? && @group.addresses.none? { |address| address.id == id.to_i }
    end
end
