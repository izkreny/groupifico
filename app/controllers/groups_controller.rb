class GroupsController < ApplicationController
  before_action :set_group, only: %i[ show edit update destroy ]

  def index
    authorize! Group, to: :index?

    @groups = authorized_scope(Group.all)
    # The reader's own standing in each group, which is what the card's tag says. Loaded once and
    # keyed by group, because a card that looked its own membership up would cost a query each -
    # the same association and the same preload the layout already makes for the switcher.
    @memberships = Current.user.current_memberships.includes(:roles).index_by(&:group_id)
  end

  def show
    authorize! @group

    # `Current.member` answers nil here: `GroupScoped` assigns `Current.group` from
    # `params[:group_id]`, and this controller is not nested under a group. The membership cannot be
    # nil by the time this runs - `GroupPolicy`'s membership pre-check raises 404 for a non-member
    # above - and the hero tolerates nil anyway, through `Event#registration_for`'s `member&.id`.
    @membership = @group.members.find_by(user: Current.user)
    # The group decides which event is next, not the screen - the same reading `events#index` takes.
    # No preload: the hero's "said yes" line queries with the names included itself, and its counts
    # are one grouped query, so the only association a screen leaves it to load is `registrations`.
    @next_event = @group.next_event
  end

  def new
    @group         = Group.new(group_type: Current.brand.group_type)
    @group.address = Address.new

    authorize! @group
  end

  def edit
    @group.address = Address.new unless @group.address

    authorize! @group
  end

  def create
    @group = Group.new(group_params)
    @group.add_owner(Current.user)

    authorize! @group

    if @group.save
      redirect_to group_path(@group),
        notice: "Group was successfully created."
    else
      # The same seeding `new` and `edit` do, because this renders `new`. Without it a refused save
      # sends the reader back to a screen missing the block they left: `reject_if` drops an address
      # nobody typed into, so `@group.address` is nil and the form draws no "Where you meet" at all.
      @group.address ||= Address.new

      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @group

    if @group.update(group_params)
      redirect_to group_path(@group),
        notice: "Group was successfully updated.",
        status: :see_other
    else
      # The same reason `create` seeds it: this renders `edit`, and a group that never named a
      # place arrives here with no address to draw the block from.
      @group.address ||= Address.new

      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @group

    @group.destroy!

    redirect_to groups_path,
      notice: "Group was successfully destroyed.",
      status: :see_other
  end

  private
    def set_group
      @group = Group.find(params.expect(:id))
    end

    def group_params
      params.expect(
        group: [
          :name, :description, :group_type,
          address_attributes: [
            :id, :name, :street_name, :building_number, :city, :postal_code, :state_code, :country_code, :latitude, :longitude
          ]
        ]
      )
    end
end
