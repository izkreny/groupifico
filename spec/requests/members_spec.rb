require 'rails_helper'

RSpec.describe "Members", type: :request do
  describe "GET /groups/:group_id/members" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get group_members_path(create(:group))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        sign_in_as(create(:user))

        get group_members_path(create(:group))

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the members page" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_members_path(member.group)

        expect(response).to have_http_status :ok
      end

      it "lists only members from groups the acting user belongs to" do
        member = create(:member, :active)
        other_member = create(:member)
        sign_in_as(member.user)

        get group_members_path(member.group)

        expect(response.body).to include(ActionView::RecordIdentifier.dom_id(member))
        expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(other_member))
      end
    end
  end

  describe "GET /groups/:group_id/members/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        member = create(:member)

        get group_member_path(member.group, member)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        member = create(:member)
        sign_in_as(create(:user))

        get group_member_path(member.group, member)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the member page" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_member_path(member.group, member)

        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as a paused member" do
      it "shows the member page" do
        target = create(:member)
        viewer = create(:member, :paused, group: target.group)
        sign_in_as(viewer.user)

        get group_member_path(target.group, target)

        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as an inactive member" do
      it "returns 404, exactly like a non-member" do
        target = create(:member)
        viewer = create(:member, :inactive, group: target.group)
        sign_in_as(viewer.user)

        get group_member_path(target.group, target)

        expect(response).to have_http_status :not_found
      end
    end
  end

  describe "GET /groups/:group_id/members/new" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get new_group_member_path(create(:group))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        sign_in_as(create(:user))

        get new_group_member_path(create(:group))

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the new member page" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get new_group_member_path(member.group)

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "GET /groups/:group_id/members/:id/edit" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        member = create(:member)

        get edit_group_member_path(member.group, member)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        member = create(:member)
        sign_in_as(create(:user))

        get edit_group_member_path(member.group, member)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the edit member page" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get edit_group_member_path(member.group, member)

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "POST /groups/:group_id/members" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        group = create(:group)

        post group_members_path(group), params: { member: { user_id: create(:user).id } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and does not create the membership - closing the self-promotion path" do
        group = create(:group)
        user  = create(:user)
        sign_in_as(user)

        expect { post group_members_path(group), params: { member: { user_id: user.id } } }
          .not_to change(Member, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "ignores a posted role name outside the vocabulary" do
        actor   = create(:member, :active)
        invitee = create(:user)
        sign_in_as(actor.user)

        post group_members_path(actor.group), params: { member: { user_id: invitee.id, roles: [ "events_administrator", "bogus" ] } }

        expect(Member.find_by(user: invitee).roles.map(&:name)).to eq [ "events_administrator" ]
      end

      it "creates the member with the roles posted for them" do
        actor   = create(:member, :active)
        invitee = create(:user)
        sign_in_as(actor.user)

        post group_members_path(actor.group), params: { member: { user_id: invitee.id, roles: [ "events_administrator" ] } }

        expect(Member.find_by(user: invitee).roles.map(&:name)).to eq [ "events_administrator" ]
      end

      it "creates the member" do
        actor  = create(:member, :active)
        invitee = create(:user)
        sign_in_as(actor.user)

        expect { post group_members_path(actor.group), params: { member: { user_id: invitee.id } } }
          .to change(Member, :count).by(1)

        expect(response).to redirect_to group_member_path(actor.group, Member.find_by!(user: invitee, group: actor.group))
      end

      it "re-renders the new page when the member is invalid" do
        actor = create(:member, :active)
        sign_in_as(actor.user)

        expect { post group_members_path(actor.group), params: { member: { user_id: "" } } }
          .not_to change(Member, :count)

        expect(response).to have_http_status :unprocessable_entity
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and does not create the membership" do
        actor = create(:member, :paused)
        invitee = create(:user)
        sign_in_as(actor.user)

        expect { post group_members_path(actor.group), params: { member: { user_id: invitee.id } } }
          .not_to change(Member, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /groups/:group_id/members/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        member = create(:member)

        patch group_member_path(member.group, member), params: { member: { roles: [ "administrator" ] } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and leaves the member unchanged" do
        member = create(:member)
        sign_in_as(create(:user))

        patch group_member_path(member.group, member), params: { member: { roles: [ "administrator" ] } }

        expect(response).to have_http_status :not_found
        expect(member.reload.roles).to be_empty
      end
    end

    context "when signed in as an active member" do
      it "updates the member" do
        member = create(:member, :active)
        sign_in_as(member.user)

        patch group_member_path(member.group, member), params: { member: { roles: [ "administrator", "events_administrator" ] } }

        expect(response).to redirect_to group_member_path(member.group, member)
        expect(member.reload.roles.map(&:name)).to contain_exactly("administrator", "events_administrator")
      end

      it "ignores a posted role name outside the vocabulary" do
        member = create(:member, :active)
        sign_in_as(member.user)

        patch group_member_path(member.group, member), params: { member: { roles: [ "administrator", "bogus" ] } }

        expect(response).to redirect_to group_member_path(member.group, member)
        expect(member.reload.roles.map(&:name)).to eq [ "administrator" ]
      end

      it "grants a role posted twice exactly once" do
        member = create(:member, :active)
        sign_in_as(member.user)

        patch group_member_path(member.group, member), params: { member: { roles: [ "owner", "owner" ] } }

        expect(response).to redirect_to group_member_path(member.group, member)
        expect(member.reload.roles.map(&:name)).to eq [ "owner" ]
      end

      it "re-renders the edit page when the member is invalid" do
        member = create(:member, :active)
        sign_in_as(member.user)

        patch group_member_path(member.group, member), params: { member: { status: "" } }

        expect(response).to have_http_status :unprocessable_entity
      end

      it "ignores a posted group_id, leaving the membership in its own group" do
        member = create(:member, :active)
        original_group = member.group
        other_group = create(:group)
        sign_in_as(member.user)

        patch group_member_path(member.group, member), params: { member: { group_id: other_group.id } }

        expect(member.reload.group).to eq original_group
      end

      it "ignores a posted user_id, leaving the membership with the user it had" do
        member = create(:member, :active)
        original_user = member.user
        other_user = create(:user)
        sign_in_as(member.user)

        patch group_member_path(member.group, member), params: { member: { user_id: other_user.id } }

        expect(member.reload.user).to eq original_user
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and leaves the member unchanged" do
        member = create(:member)
        actor = create(:member, :paused, group: member.group)
        sign_in_as(actor.user)

        patch group_member_path(member.group, member), params: { member: { roles: [ "administrator" ] } }

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
        expect(member.reload.roles).to be_empty
      end
    end
  end

  describe "DELETE /groups/:group_id/members/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        member = create(:member)

        expect { delete group_member_path(member.group, member) }
          .not_to change(Member, :count)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and does not destroy the member" do
        member = create(:member)
        sign_in_as(create(:user))

        expect { delete group_member_path(member.group, member) }
          .not_to change(Member, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "destroys the member" do
        target = create(:member)
        actor = create(:member, :active, group: target.group)
        sign_in_as(actor.user)

        expect { delete group_member_path(target.group, target) }
          .to change(Member, :count).by(-1)

        expect(response).to redirect_to group_members_path(target.group)
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and does not destroy the member" do
        target = create(:member)
        actor = create(:member, :paused, group: target.group)
        sign_in_as(actor.user)

        expect { delete group_member_path(target.group, target) }
          .not_to change(Member, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end
  end
end
