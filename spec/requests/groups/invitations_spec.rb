require 'rails_helper'

RSpec.describe "Groups::Invitations", type: :request do
  describe "GET /groups/:group_id/invitation" do
    context "when not signed in" do
      it "redirects to the sign-in page, carrying the invitation to come back to" do
        group = create(:group)

        get group_invitation_path(group)

        expect(response).to redirect_to new_session_path(return_to: group_invitation_path(group))
      end
    end

    context "when signed in as an invitee" do
      it "names the group and offers Join and Decline" do
        member = create(:member, :pending, group: create(:group, name: "Riverside Choir"))
        sign_in_as member.user

        get group_invitation_path(member.group)

        page = Nokogiri::HTML(response.body)
        methods = page.css(%(form[action="#{group_invitation_path(member.group)}"] input[name="_method"])).map { it["value"] }

        expect(page_text(response.body)).to include("Riverside Choir", "You are invited to join this group.")
        expect(methods).to eq %w[ patch delete ]
      end

      # WHY: N2, the profile gate running on this page as it does on the join link's, so an invitee fills in their name and mobile before they see Join.
      it "sends an invitee without a name and a mobile to the profile form, carrying the invitation to come back to" do
        member = create(:member, :pending, user: create(:user, :not_set_up))
        sign_in_as member.user

        get group_invitation_path(member.group)

        expect(response).to redirect_to edit_user_profile_path(return_to: group_invitation_path(member.group))
      end
    end

    context "when signed in as an active member" do
      it "tells them they are already in the group, offering no Join" do
        member = create(:member, :active)
        sign_in_as member.user

        get group_invitation_path(member.group)

        expect(page_text(response.body)).to include("You are already in this group.")
        expect(response.body).not_to include(%(value="patch"))
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        group = create(:group)
        sign_in_as create(:user)

        get group_invitation_path(group)

        expect(response).to have_http_status :not_found
      end
    end
  end

  describe "PATCH /groups/:group_id/invitation" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        group = create(:group)

        patch group_invitation_path(group)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as an invitee" do
      # WHY: #505 AC2, Join making the invitee one of the group's members.
      it "makes them an active member and opens the group" do
        member = create(:member, :pending)
        sign_in_as member.user

        patch group_invitation_path(member.group)

        expect(member.reload).to be_active
        expect(response).to redirect_to group_path(member.group)
      end

      it "records their joining as an active change from the day they join, made by them rather than whoever invited them (#126 AC3)" do
        travel_to Time.zone.local(2026, 11, 2, 12)
        inviter = create(:member, :active, :members_administrator)
        member  = create(:member, :pending, group: inviter.group, status_updater: inviter)
        sign_in_as member.user
        travel_to Time.zone.local(2026, 11, 9, 12)

        patch group_invitation_path(member.group)

        expect(Member::StatusChange.where(member:).order(:starts_on).pluck(:status, :starts_on, :updater_id)).to eq [ [ "pending", Date.new(2026, 11, 2), inviter.id ], [ "active", Date.new(2026, 11, 9), member.id ] ]
      end

      # WHY: #505 AC4, the group refused until they join, and reached once they have.
      it "reaches the group's page only once they have joined" do
        member = create(:member, :pending)
        sign_in_as member.user

        get group_path(member.group)
        expect(response).to have_http_status :not_found

        patch group_invitation_path(member.group)
        get group_path(member.group)
        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as a member who left" do
      it "returns 404 and leaves them inactive" do
        member = create(:member, :inactive)
        sign_in_as member.user

        patch group_invitation_path(member.group)

        expect(response).to have_http_status :not_found
        expect(member.reload).to be_inactive
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and adds nobody" do
        group = create(:group)
        sign_in_as create(:user)

        expect { patch group_invitation_path(group) }.not_to change(Member, :count)

        expect(response).to have_http_status :not_found
      end
    end
  end

  describe "DELETE /groups/:group_id/invitation" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        group = create(:group)

        delete group_invitation_path(group)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as an invitee" do
      # WHY: #505 AC3, Decline removing the membership and nothing else.
      it "removes the pending membership, keeps the user and lands on the root page" do
        member = create(:member, :pending)
        sign_in_as member.user

        delete group_invitation_path(member.group)

        expect(Member.exists?(member.id)).to be false
        expect(User.exists?(member.user_id)).to be true
        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as an active member" do
      it "returns 404 and leaves the membership in place" do
        member = create(:member, :active)
        sign_in_as member.user

        delete group_invitation_path(member.group)

        expect(response).to have_http_status :not_found
        expect(Member.exists?(member.id)).to be true
      end
    end
  end
end
