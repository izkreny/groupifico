# Creating a group's join link, regenerating it, and deleting it. `create` does both of the first two, since either mints a link that retires the one before it. Both actions authorize `MemberPolicy#create?`, asked of a member with nothing on it but the group, because the join link row of the Members table in `docs/AUTHORIZATION.md` marks the three columns that add a person.
class Groups::JoinLinksController < ApplicationController
  include GroupScoped

  def create
    authorize! Member.new(group: @group), to: :create?

    JoinLink.mint(@group)

    redirect_to group_members_path(@group)
  end

  def destroy
    authorize! Member.new(group: @group), to: :create?

    @group.join_link&.destroy!

    redirect_to group_members_path(@group), status: :see_other
  end
end
