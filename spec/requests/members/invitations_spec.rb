require 'rails_helper'

RSpec.describe "Members::Invitations", type: :request do
  describe "POST /groups/:group_id/members/:member_id/invitation" do
    context "when not signed in" do
      it "redirects to the sign-in page and sends nothing" do
        invitee = create(:member, :pending)

        expect { post group_member_invitation_path(invitee.group, invitee) }.not_to have_enqueued_mail

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and sends nothing" do
        invitee = create(:member, :pending)
        sign_in_as create(:user)

        expect { post group_member_invitation_path(invitee.group, invitee) }.not_to have_enqueued_mail

        expect(response).to have_http_status :not_found
      end
    end

    # The *Add a person* row, one context per column, because resending is inviting again.
    context "when signed in as an owner" do
      it "sends the pending member their invitation again and returns to the Invited tab" do
        actor   = create(:member, :active, :owner)
        invitee = create(:member, :pending, group: actor.group)
        sign_in_as actor.user

        expect { post group_member_invitation_path(actor.group, invitee) }
          .to have_enqueued_mail(MemberMailer, :invitation).with(invitee)

        expect(response).to redirect_to group_members_path(actor.group, status: "pending")
      end
    end

    context "when signed in as an administrator" do
      it "sends the pending member their invitation again and returns to the Invited tab" do
        actor   = create(:member, :active, :administrator)
        invitee = create(:member, :pending, group: actor.group)
        sign_in_as actor.user

        expect { post group_member_invitation_path(actor.group, invitee) }
          .to have_enqueued_mail(MemberMailer, :invitation).with(invitee)

        expect(response).to redirect_to group_members_path(actor.group, status: "pending")
      end
    end

    context "when signed in as a members administrator" do
      it "sends the pending member their invitation again and returns to the Invited tab" do
        actor   = create(:member, :active, :members_administrator)
        invitee = create(:member, :pending, group: actor.group)
        sign_in_as actor.user

        expect { post group_member_invitation_path(actor.group, invitee) }
          .to have_enqueued_mail(MemberMailer, :invitation).with(invitee)

        expect(response).to redirect_to group_members_path(actor.group, status: "pending")
      end
    end

    context "when signed in as an events administrator" do
      it "refuses and sends nothing" do
        actor   = create(:member, :active, :events_administrator)
        invitee = create(:member, :pending, group: actor.group)
        sign_in_as actor.user

        expect { post group_member_invitation_path(actor.group, invitee) }.not_to have_enqueued_mail

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a member holding no role" do
      it "refuses alike for a pending member and an id nobody holds, sending nothing" do
        actor   = create(:member, :active)
        invitee = create(:member, :pending, group: actor.group)
        sign_in_as actor.user

        expect { post group_member_invitation_path(actor.group, invitee) }.not_to have_enqueued_mail
        expect(response).to redirect_to root_path

        post group_member_invitation_path(actor.group, 0)
        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a paused owner" do
      it "refuses, because resending is a write, and sends nothing" do
        actor   = create(:member, :paused, :owner)
        invitee = create(:member, :pending, group: actor.group)
        sign_in_as actor.user

        expect { post group_member_invitation_path(actor.group, invitee) }.not_to have_enqueued_mail

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end

    context "when the member has already joined" do
      it "returns 404 and sends nothing" do
        actor  = create(:member, :active, :owner)
        member = create(:member, :active, group: actor.group)
        sign_in_as actor.user

        expect { post group_member_invitation_path(actor.group, member) }.not_to have_enqueued_mail

        expect(response).to have_http_status :not_found
      end
    end
  end
end
