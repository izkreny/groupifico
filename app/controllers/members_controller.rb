class MembersController < ApplicationController
  # A posted role name outside `Role::NAMES` is refused rather than dropped: an all-unknown list
  # would filter to nothing, and `roles=` reads nothing as "hold no roles", which would revoke
  # every role the member has and answer with a success.
  rescue_from Role::UnknownName, with: :refuse_unknown_role
  # A group must keep an owner, which Member and Role enforce with `throw :abort`. It surfaces here
  # as RecordNotDestroyed from either end - removing the last owner, or revoking their role, which
  # destroys the row without the member being touched - and it is a refusal the acting member can
  # act on rather than a fault, so it gets a message instead of a 500.
  rescue_from ActiveRecord::RecordNotDestroyed, with: :refuse_ownerless_group

  include GroupScoped

  before_action :set_member, only: %i[ show edit update destroy ]

  def index
    authorize! @group, to: :show?

    # WHY: `Member::Filter` picks the tab and every filter from its own literals, as `Event::Filter` does for the events list. Pending and Inactive are `MemberPolicy#oversee?` reads, asked of a member with nothing on it but the group, and a reader not offered them gets the Active list rather than a refusal, the way an unknown event list degrades to Upcoming.
    @filter = Member::Filter.from(Current.member, params, oversees: allowed_to?(:oversee?, Member.new(group: @group)))

    members = authorized_scope(@group.members)
    @counts = @filter.counts(members)
    # WHY: sorted in Ruby rather than ordered in SQL, because `full_name` falls back to the address
    # when the profile has no name, and ordering on the profile's columns would misplace that member.
    @members = @filter.apply(members).preloaded.sort_by { it.full_name.downcase }
  end

  def show
    authorize! @member

    @managed_events = @member.managed_events.order(:starts_at)
  end

  def new
    @member = @group.members.new

    authorize! @member
  end

  def edit
    authorize! @member
  end

  # WHY: pending and holding no role whatever the form posts, because an invitation asks for an address and nothing else and the invitee is let in by their own Join; any status or role is set on the edit form once they have joined.
  def create
    @member = @group.members.new(email: params.expect(member: [ :email ])[:email], status: :pending)

    authorize! @member

    # WHY: sent from here rather than from a callback on `Member`, which would also mail every owner
    # `Group#add_owner` makes for themselves when they start a group.
    if @member.save
      MemberMailer.invitation(@member).deliver_later

      redirect_to group_member_path(@group, @member),
        notice: "Invitation sent to #{@member.email}."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @member

    attributes = member_params
    authorize! @member, to: :manage_roles? if granting_roles?(attributes)

    if update_with_status(attributes)
      redirect_to group_member_path(@group, @member),
        notice: "Member was successfully updated.",
        status: :see_other
    else
      render :edit, status: :unprocessable_content
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
    def set_member
      @member = @group.members.preloaded.find(params.expect(:id))
    end

    # Used on update: the address stays out, so an existing membership cannot be handed to a
    # different user. Who may set a role is `MemberPolicy#manage_roles?`, asked above.
    def member_params
      role_records params.expect(member: [ :status, :status_starts_on, roles: [] ]), held: @member.roles
    end

    # WHY: a status moves through `change_status`, never a plain write, so its change is recorded; it runs in one transaction with the roles, so a refused status leaves the roles as they were, as one `update` did. A start date posted with an unchanged status is ignored, since nothing starts on it, and one not posted at all is today.
    def update_with_status(attributes)
      posted = attributes.extract!(:status, :status_starts_on)

      saved = Member.transaction do
        @member.assign_attributes(attributes)

        written = if posted.key?(:status) && posted[:status] != @member.status
          @member.change_status(posted[:status], starts_on: posted.fetch(:status_starts_on) { @member.status_starts_on })
        else
          @member.save
        end

        raise ActiveRecord::Rollback unless written
        true
      end

      # WHY: a refused event puts the saved status back, so the form is handed the posted one to show what was picked.
      @member.status = posted[:status] if !saved && posted[:status].in?(Member.statuses.keys)
      saved
    end

    # A posted `roles` key that changes nothing is not a grant. The member form draws its role
    # checkboxes only for an acting user who may grant roles, but a form loaded while they could
    # and submitted after they no longer can still carries the unchanged list, and refusing the
    # status change over it would be a defect in this check rather than a rule doing its job. Names
    # are already unique here, so sorting compares the sets.
    def granting_roles?(attributes)
      return false unless attributes.key?(:roles)

      attributes[:roles].map(&:name).sort != @member.roles.map(&:name).sort
    end

    # Roles arrive as names and the association writer wants records, so the swap happens here
    # rather than as a second writer on the model that accepts both. Repeats collapse, and an empty
    # list stays an instruction rather than an omission, and it means "hold no roles".
    #
    # WHY: a name the member already holds keeps its row. Swapping it for a fresh record destroys
    # the old row first, and `Role`'s owner guard refuses that for the group's last owner even
    # though the role stays, so the only owner could not save their own form at all.
    def role_records(permitted, held:)
      return permitted unless permitted.key?(:roles)

      role_names = permitted[:roles].compact_blank.uniq
      raise Role::UnknownName if role_names.difference(Role::NAMES).any?

      held_by_name = held.index_by(&:name)
      permitted.merge(roles: role_names.map { held_by_name[it] || Role.new(name: it) })
    end

    def refuse_unknown_role
      head :unprocessable_content
    end

    def refuse_ownerless_group
      redirect_to group_member_path(@group, @member),
        alert: "A group must always have an owner.",
        status: :see_other
    end
end
