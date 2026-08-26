require 'rails_helper'

RSpec.describe "Members", type: :request do
  describe "GET /groups/:group_id/members" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get group_members_path(create(:group))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows the members page" do
        sign_in_as(create(:user))

        get group_members_path(create(:group))

        expect(response).to have_http_status :ok
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

    context "when successfully signed in" do
      it "shows the member page" do
        member = create(:member)
        sign_in_as(create(:user))

        get group_member_path(member.group, member)

        expect(response).to have_http_status :ok
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

    context "when successfully signed in" do
      it "shows the new member page" do
        sign_in_as(create(:user))

        get new_group_member_path(create(:group))

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

    context "when successfully signed in" do
      it "shows the edit member page" do
        member = create(:member)
        sign_in_as(create(:user))

        get edit_group_member_path(member.group, member)

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "POST /groups/:group_id/members" do
    let(:group) { create(:group) }

    context "when not signed in" do
      it "redirects to the sign-in page" do
        post group_members_path(group), params: { member: { user_id: create(:user).id } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "creates the member" do
        user = create(:user)
        sign_in_as(user)

        expect { post group_members_path(group), params: { member: { user_id: user.id } } }.to change(Member, :count).by(1)

        expect(response).to redirect_to group_member_path(group, Member.find_by!(user:, group:))
      end

      it "re-renders the new page when the member is invalid" do
        sign_in_as(create(:user))

        expect { post group_members_path(group), params: { member: { user_id: "" } } }
          .not_to change(Member, :count)

        expect(response).to have_http_status :unprocessable_entity
      end
    end
  end

  describe "PATCH /groups/:group_id/members/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        member = create(:member)

        patch group_member_path(member.group, member), params: { member: { role: "admin" } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "updates the member" do
        member = create(:member)
        sign_in_as(create(:user))

        patch group_member_path(member.group, member), params: { member: { role: "admin" } }

        expect(response).to redirect_to group_member_path(member.group, member)
        expect(member.reload.role).to eq "admin"
      end

      it "re-renders the edit page when the member is invalid" do
        member = create(:member)
        sign_in_as(create(:user))

        patch group_member_path(member.group, member), params: { member: { user_id: "" } }

        expect(response).to have_http_status :unprocessable_entity
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

    context "when successfully signed in" do
      it "destroys the member" do
        member = create(:member)
        sign_in_as(create(:user))

        expect { delete group_member_path(member.group, member) }
          .to change(Member, :count).by(-1)

        expect(response).to redirect_to group_members_path(member.group)
      end
    end
  end
end
