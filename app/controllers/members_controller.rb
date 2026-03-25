class MembersController < ApplicationController
  before_action :set_group
  before_action :set_member, only: %i[ show edit update destroy ]

  # GET /members
  def index
    @members = @group.members # TODO: Set up active and paused ones as default
  end

  # GET /members/1
  def show
  end

  # GET /members/new
  def new
    @member = @group.members.new
  end

  # GET /members/1/edit
  def edit
  end

  # POST /members
  def create
    @member = @group.members.new(member_params)

    if @member.save
      redirect_to [ @group, @member ], notice: "Member was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /members/1
  def update
    if @member.update(member_params)
      redirect_to group_member_path, notice: "Member was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /members/1
  def destroy
    @member.destroy!

    redirect_to group_members_path, notice: "Member was successfully destroyed.", status: :see_other
  end

  private
    def set_group
      @group = Group.find(params.expect(:group_id))
    end

    def set_member
      @member = @group.members.find(params.expect(:id))
    end

    def member_params
      params.expect(member: [ :role, :status, :group_id, :user_id ])
    end
end
