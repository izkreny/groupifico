class GroupsController < ApplicationController
  before_action :set_group, only: %i[ show edit update destroy ]

  def index
    @groups = Group.all
  end

  def show
  end

  def new
    @group         = Group.new
    @group.address = Address.new
  end

  def edit
    @group.address = Address.new unless @group.address
  end

  def create
    @group = Group.new(group_params)

    if @group.save
      redirect_to @group, notice: "Group was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @group.update(group_params)
      redirect_to @group, notice: "Group was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @group.destroy!

    redirect_to groups_path, notice: "Group was successfully destroyed.", status: :see_other
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
