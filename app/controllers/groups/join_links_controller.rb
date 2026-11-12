# Turning a group's join link on, regenerating it, and turning it off. `create` does both of the first two, since either mints a link that retires the one before it. Both actions authorize `GroupPolicy#update?`, the owner's alone, which is the join link row of the Group table in `docs/AUTHORIZATION.md`.
class Groups::JoinLinksController < ApplicationController
  include GroupScoped

  def create
    authorize! @group, to: :update?

    JoinLink.mint(@group)

    redirect_to edit_group_path(@group)
  end

  def destroy
    authorize! @group, to: :update?

    @group.join_link&.destroy!

    redirect_to edit_group_path(@group), notice: "Join link turned off.", status: :see_other
  end
end
