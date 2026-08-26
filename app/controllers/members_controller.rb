class MembersController < ApplicationController
  before_action :set_group
  before_action :set_member, only: %i[ show edit update destroy ]

  def index
    authorize! @group, to: :show?

    @members = authorized_scope(@group.members) # TODO: Set up active and paused ones as default
  end

  def show
    authorize! @member
  end

  def new
    @member = @group.members.new

    authorize! @member
  end

  def edit
    authorize! @member
  end

  def create
    @member = @group.members.new(new_member_params)

    authorize! @member

    if @member.save
      redirect_to group_member_path(@group, @member),
        notice: "Member was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize! @member

    if @member.update(member_params)
      redirect_to group_member_path(@group, @member),
        notice: "Member was successfully updated.",
        status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! @member

    @member.destroy!

    redirect_to group_members_path(@group),
      notice: "Member was successfully destroyed.",
      status: :see_other
  end

  private
    def set_group
      @group = Group.find(params.expect(:group_id))
    end

    def set_member
      @member = @group.members.find(params.expect(:id))
    end

    # Used on create: deciding which person a membership is for is what creating one means.
    def new_member_params
      params.expect(member: [ :role, :status, :user_id ])
    end

    # Used on update: user_id stays out, so an existing membership cannot be handed to a
    # different user. :role stays untouched here too - who may set it is #93 and #96's question.
    def member_params
      params.expect(member: [ :role, :status ])
    end
end
