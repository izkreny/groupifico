class GroupsController < ApplicationController
  before_action :set_group, only: %i[ show edit update destroy ]

  def index
    authorize! Group, to: :index?

    @groups = authorized_scope(Group.all)
  end

  def show
    authorize! @group
  end

  def new
    @group         = Group.new
    @group.address = Address.new

    authorize! @group
  end

  def edit
    @group.address = Address.new unless @group.address

    authorize! @group
  end

  def create
    @group = Group.new(group_params)
    @group.members.build(user: Current.user, role: :owner)

    authorize! @group

    if @group.save
      redirect_to group_path(@group),
        notice: "Group was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize! @group

    if @group.update(group_params)
      redirect_to group_path(@group),
        notice: "Group was successfully updated.",
        status: :see_other
    else
      render :edit, status: :unprocessable_entity
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
