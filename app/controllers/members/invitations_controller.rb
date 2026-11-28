# Resending a pending member's invitation, from their row on the Invited tab.
class Members::InvitationsController < ApplicationController
  include GroupScoped

  # WHY: authorized as `MemberPolicy#create?` on a member with nothing on it but the group, as `Groups::JoinLinksController` is, because resending is inviting again; asked before the lookup, so a member the row does not admit gets one refusal for every id and learns nothing about which are pending.
  def create
    authorize! Member.new(group: @group), to: :create?

    member = @group.members.pending.find(params.expect(:member_id))
    MemberMailer.invitation(member).deliver_later

    redirect_to group_members_path(@group, status: "pending"), notice: "Invitation sent again.", status: :see_other
  end
end
