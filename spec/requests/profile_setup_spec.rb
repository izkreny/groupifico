require 'rails_helper'

# WHY: #472 AC1. `ProfileSetup` runs before every action, so it is proven across a sample of pages rather than in any one controller's file.
RSpec.describe "ProfileSetup", type: :request do
  context "when the signed-in user's profile lacks a first name and a mobile" do
    it "sends them from the groups list to the profile form" do
      sign_in_as(create(:user, :not_set_up))

      get groups_path

      expect(response).to redirect_to edit_user_profile_path(return_to: groups_path)
      expect(flash[:info]).to eq "Add your first name and mobile to continue."
    end

    it "sends them from a group's page, carrying the page to come back to" do
      member = create(:member, user: create(:user, :not_set_up))
      sign_in_as(member.user)

      get group_path(member.group)

      expect(response).to redirect_to edit_user_profile_path(return_to: group_path(member.group))
    end

    it "sends them from the join page, which a visitor reaches signed out" do
      token = JoinLink.mint(create(:group))
      sign_in_as(create(:user, :not_set_up))

      get new_join_request_path(token:)

      expect(response).to redirect_to edit_user_profile_path(return_to: new_join_request_path(token:))
    end

    it "refuses a write, with nothing to come back to" do
      sign_in_as(create(:user, :not_set_up))

      expect { post groups_path, params: { group: { name: "Riverside Choir" } } }.not_to change(Group, :count)

      expect(response).to redirect_to edit_user_profile_path
    end

    it "sends them when only the mobile is missing" do
      user = create(:user, :not_set_up)
      user.profile.update!(first_name: "Ada")
      sign_in_as(user)

      get groups_path

      expect(response).to redirect_to edit_user_profile_path(return_to: groups_path)
    end

    it "draws the profile form itself" do
      sign_in_as(create(:user, :not_set_up))

      get edit_user_profile_path

      expect(response).to have_http_status :ok
    end
  end

  context "when the signed-in user's profile holds both" do
    it "lets them through" do
      sign_in_as(create(:user))

      get groups_path

      expect(response).to have_http_status :ok
    end
  end
end
