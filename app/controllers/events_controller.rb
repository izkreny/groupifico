class EventsController < ApplicationController
  # WHY: what the form picks for an event not yet saved, which nobody has listed anybody for. The screens set it rather than the model, so an event built anywhere else fills nothing unless told to, and a saved event's form stays on Not now.
  RESERVED_FOR_A_NEW_EVENT = "reserve".freeze

  MOVED_ON = "Nothing was saved: somebody changed the list while you were editing it. Here it is again.".freeze

  include GroupScoped

  before_action :set_event, only: %i[ show duplicate edit update destroy ]

  def index
    authorize! @group, to: :show?

    # WHY: picked from literals rather than naming a scope from the parameter, because `params[:scope]` is a member's input, and anything built out of it and sent to the relation is a door onto every scope the model has. Anything else is `nil`, the upcoming list, so a mistyped URL degrades to the default list. The values are spelled again in `events/_scope_menu` and in the empty text of `events/index`.
    @list = params[:scope].presence_in(%w[ past canceled ])

    # Preloaded because every row reads the event for the reader's own registration and its place,
    # and `Event#registration_for` reads the loaded association: without this the list costs a
    # query per row for each.
    #
    # Ordered here because the list had no order at all: the rows were whatever the database
    # happened to return, which is the same list in a different sequence on a different day.
    #
    # The scopes partition the group's events between them, so an event it is in the middle of is on the upcoming list rather than on none: still ahead of its members, not behind them.
    events = authorized_scope(@group.events).preloaded
    @events = case @list
    when "past" then events.past.order(starts_at: :desc)
    when "canceled" then events.canceled.order(starts_at: :desc)
    else events.current_and_upcoming.order(:starts_at)
    end
  end

  def show
    authorize! @event
  end

  def new
    @event = @group.events.new(list_filling: RESERVED_FOR_A_NEW_EVENT)
    @event.build_address

    authorize! @event
  end

  # Authorizes create?, not show?: what this action reads is incidental, what it offers is a form
  # for making a new event. `new` resolves new? through create?, so authorizing show? here made two
  # doors onto the same form disagree - a paused member was refused at one and admitted at the other.
  #
  # The source stays in `@original`, because the screen says which event was copied and from when.
  def duplicate
    authorize! @event, to: :create?

    @original = @event
    @event = @original.duplicate.shift_by(7.days)
    @event.list_filling = RESERVED_FOR_A_NEW_EVENT
    @event.build_address unless @event.address
  end

  def edit
    @event.build_address unless @event.address

    authorize! @event
  end

  def create
    @event = @group.events.new(event_params)

    authorize! @event
    authorize_reservation!

    if @event.save
      @event.fill_list

      redirect_to group_event_path(@group, @event),
        notice: "Event was successfully created."
    else
      @event.build_address unless @event.address

      # WHY: looked up within the group, so a forged id cannot draw another group's event, and with
      # `find_by`, so one that resolves to nothing falls back to the new event screen rather than
      # throwing away what was typed.
      @original = @group.events.find_by(id: params[:original_id])

      render(@original ? :duplicate : :new, status: :unprocessable_content)
    end
  end

  # WHY: who is on the list saves with the event, all or nothing, so a refused save leaves the list as it was and the form draws the posted marks again. Both rules are checked against the event as it was loaded, before anything is assigned, so handing it on in the same save decides nothing about this reader's own changes.
  def update
    authorize! @event
    authorize_list_changes!
    @list_editable = allowed_to?(:create?, Registration.new(event: @event))

    if list_moved_on?
      @event.assign_attributes(event_params)
      draw_moved_on
    else
      saved = @event.transaction do
        @event.update(event_params).tap do |updated|
          @event.update_roster(arriving: arriving_members, leaving: leaving_registrations) if updated
        end
      end

      if saved
        redirect_to group_event_path(@group, @event),
          notice: "Event was successfully updated.",
          status: :see_other
      else
        @event.build_address unless @event.address

        render :edit, status: :unprocessable_content
      end
    end
  rescue ActiveRecord::RecordNotUnique
    # WHY: a member added here landed on the list from somewhere else while this request was writing; the transaction has rolled the whole save back, so the form is drawn again as it was posted.
    draw_moved_on
  end

  def destroy
    authorize! @event

    @event.destroy!

    redirect_to group_events_path(@group),
      notice: "Event was successfully destroyed.",
      status: :see_other
  end

  private
    def set_event
      @event = @group.events.preloaded.find(params.expect(:id))
    end

    # The foreign keys the form submits are checked rather than trusted. Each picker is already
    # scoped to this group - `group.members` and `group.addresses` - but the parameters are not, and
    # an unscoped foreign key in the body is the same boundary-crossing the unscoped lookup was,
    # arriving by another door. `:address_id` is the one with teeth: pointing an event at another
    # group's address makes this event one of that address's owners, and `AddressPolicy` reads the
    # owners, so it hands the address to somebody with no claim on it. Absent from the list because
    # nothing may name them: `:group_id`, which the URL supplies, and `:creator_id`, which the model
    # answers from the acting member.
    #
    # `address_attributes` permits no `:id`, which is what keeps editing an address out of this
    # controller entirely. With one, `accepts_nested_attributes_for` updates the named address in
    # place and only `EventPolicy#update?` is ever checked - so whoever may edit the event edits the
    # address too, the group's home address included, which `AddressPolicy` reserves to the `owner`.
    # Without one, the nested attributes can only build a new address, which is what the form wants
    # when "New address…" is picked; a saved address is corrected at `AddressesController#edit`,
    # where the rule is checked properly.
    #
    # The form draws those fields whichever row is picked, so they arrive beside an `address_id` too,
    # and assigned after it they would build a new address that replaces the pick. A picked address
    # is used as it is, so an `address_id` wins and the typed fields are dropped. A blank one is the
    # "New address…" row, and leaves them to build.
    def event_params
      params.expect(
        event: [ :name, :description, :starts_at, :ends_at, :status, :category,
          :manager_id, :address_id, :list_filling,
          address_attributes: [
            :name, :street_name, :building_number, :city, :postal_code, :state_code, :country_code, :latitude, :longitude
          ]
        ]
      ).tap do |permitted|
        permitted.delete(:manager_id) if foreign_member?(permitted[:manager_id])
        permitted.delete(:address_id) if foreign_address?(permitted[:address_id])
        permitted.delete(:address_attributes) if permitted[:address_id].present?
      end
    end

    # WHY: the event is already built from the params here, and `EventPolicy#create?` admitting `can_manage?(:events)` alone is what keeps that safe.
    def authorize_reservation!
      authorize! Registration.new(event: @event), to: :create? if params.dig(:event, :list_filling).present?
    end

    def authorize_list_changes!
      authorize! Registration.new(event: @event), to: :create? if posted_ids(:adding_ids).any?
      authorize! Registration.new(event: @event), to: :destroy? if posted_ids(:removing_ids).any?
    end

    # WHY: only those the form would still offer, rather than the ids as posted: one naming somebody from another group would publish their name through the event's list, and one already registered while the form sat open is dropped here rather than reaching the unique index.
    def arriving_members
      @group.members.active.without_registration_for(@event).where(id: posted_ids(:adding_ids))
    end

    # WHY: a member marked with `+` the form no longer offers was paused, deactivated or listed while it sat open, and saving without them would report success for a list the reader did not ask for, so the whole save is refused.
    def list_moved_on?
      arriving_members.count < posted_ids(:adding_ids).uniq.size
    end

    def draw_moved_on
      flash.now[:alert] = MOVED_ON
      @event.build_address unless @event.address

      render :edit, status: :unprocessable_content
    end

    def leaving_registrations
      @event.registrations.where(member_id: posted_ids(:removing_ids))
    end

    def posted_ids(key)
      params.key?(key) ? params.expect(key => []).compact_blank : []
    end

    # Present and not ours. A blank passes straight through so the model decides what it means:
    # `manager` is optional and is cleared. Dropping blanks here instead would silently turn
    # "remove the manager" into "leave it alone".
    def foreign_member?(id)
      id.present? && !@group.members.exists?(id)
    end

    def foreign_address?(id)
      id.present? && !@group.addresses.exists?(id)
    end
end
