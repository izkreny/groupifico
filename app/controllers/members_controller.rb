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
      role_records params.expect(member: [ :status, :user_id, roles: [] ])
    end

    # Used on update: user_id stays out, so an existing membership cannot be handed to a
    # different user. Who may set a role is still #96's and #173's question.
    def member_params
      role_records params.expect(member: [ :status, roles: [] ])
    end

    # Roles arrive as names and the association writer wants records, so the swap happens here
    # rather than as a second writer on the model that accepts both.
    def role_records(permitted)
      return permitted unless permitted.key?(:roles)

      permitted.merge(roles: permitted[:roles].compact_blank.map { Role.new(name: it) })
    end
end
