class GroupsController < ApplicationController
  before_action :set_group, only: %i[ show edit update destroy ]

  # GET /groups
  def index
    @groups = Group.all
  end

  # GET /groups/1
  def show
  end

  # GET /groups/new
  def new
    @group         = Group.new
    @group.address = Address.new
  end

  # GET /groups/1/edit
  def edit
    @group.address = Address.new unless @group.address
  end

  # POST /groups
  def create
    @group = Group.new(group_params)

    if @group.save
      redirect_to @group, notice: "Group was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /groups/1
  def update
    if @group.update(group_params)
      redirect_to @group, notice: "Group was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /groups/1
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
