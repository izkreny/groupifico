# The invitee's side of an invitation: the join page reached by the group rather than by a join link's token, and the Join and Decline it offers.
class Groups::InvitationsController < ApplicationController
  # Permanent, all three: the membership is found through the caller's own session and never named by the URL, so a rule would have one possible input and one possible answer, the argument `UsersController#destroy` makes; and both pre-checks in `ApplicationPolicy` refuse a pending member, so a policy would have to skip them to say anything at all. `docs/AUTHORIZATION.md` records it under the records with no group at all.
  skip_verify_authorized only: %i[ show update destroy ]

  include GroupScoped

  layout "entry"

  before_action :set_member, only: :show
  before_action :set_pending_member, only: %i[ update destroy ]

  # WHY: the link join page's own template, so an invitee and a link joiner end on one screen; it reads `@group` and `@member`, and a member of any status gets the answer that page gives them.
  def show
    render "join_requests/new"
  end

  # WHY: a plain status write, as ADR 0008 says #505 ships until #126 moves it onto the join event.
  def update
    @member.update!(status: :active)

    redirect_to group_path(@group), notice: "You joined #{@group.name}.", status: :see_other
  end

  def destroy
    @member.destroy!

    redirect_to root_path, notice: "You declined the invitation to #{@group.name}.", status: :see_other
  end

  private
    def set_member
      @member = Current.user.members.find_by!(group: @group)
    end

    # WHY: pending only, so Join cannot bring back a member who left and Decline cannot remove one who already belongs; either answers the 404 a missing invitation does.
    def set_pending_member
      @member = Current.user.members.pending.preloaded.find_by!(group: @group)
    end
end
