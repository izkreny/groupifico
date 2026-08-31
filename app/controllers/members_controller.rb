class MembersController < ApplicationController
  # A posted role name outside `Role::NAMES` is refused rather than dropped: an all-unknown list
  # would filter to nothing, and `roles=` reads nothing as "hold no roles", which would revoke
  # every role the member has and answer with a success.
  rescue_from Role::UnknownName, with: :refuse_unknown_role

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
    authorize! @member, to: :manage_roles? if @member.roles.any?

    if @member.save
      redirect_to group_member_path(@group, @member),
        notice: "Member was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize! @member

    attributes = member_params
    authorize! @member, to: :manage_roles? if granting_roles?(attributes)

    if @member.update(attributes)
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

    # A posted `roles` key that changes nothing is not a grant. #193 puts role checkboxes on the
    # member form, after which every status change posts the roles the member already holds, and
    # refusing an administrator their own row over an unchanged list would be a defect in this
    # check rather than a rule doing its job. Names are already unique here, so sorting compares
    # the sets.
    def granting_roles?(attributes)
      return false unless attributes.key?(:roles)

      attributes[:roles].map(&:name).sort != @member.roles.map(&:name).sort
    end

    # Roles arrive as names and the association writer wants records, so the swap happens here
    # rather than as a second writer on the model that accepts both. Repeats collapse, and an empty
    # list stays an instruction rather than an omission, and it means "hold no roles".
    def role_records(permitted)
      return permitted unless permitted.key?(:roles)

      role_names = permitted[:roles].compact_blank.uniq
      raise Role::UnknownName if role_names.difference(Role::NAMES).any?

      permitted.merge(roles: role_names.map { Role.new(name: it) })
    end

    def refuse_unknown_role
      head :unprocessable_entity
    end
end
