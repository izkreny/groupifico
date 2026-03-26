class MembersController < ApplicationController
  before_action :set_group
  before_action :set_member, only: %i[ show edit update destroy ]

  def index
    @members = @group.members # TODO: Set up active and paused ones as default
  end

  def show
  end

  def new
    @member = @group.members.new
  end

  def edit
  end

  def create
    @member = @group.members.new(member_params)

    if @member.save
      redirect_to [ @group, @member ], notice: "Member was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @member.update(member_params)
      redirect_to group_member_path, notice: "Member was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

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
