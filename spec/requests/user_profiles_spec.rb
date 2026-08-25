require 'rails_helper'

RSpec.describe "UserProfiles", type: :request do
  describe "GET /user/profile" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get user_profile_path

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows the profile page" do
        sign_in_as(create(:user))

        get user_profile_path

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "GET /user/profile/edit" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get edit_user_profile_path

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows the edit profile page" do
        sign_in_as(create(:user))

        get edit_user_profile_path

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "PATCH /user/profile" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        patch user_profile_path, params: { user_profile: { first_name: "Ada" } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "updates the profile" do
        user = create(:user)
        sign_in_as(user)

        patch user_profile_path, params: { user_profile: { first_name: "Ada", last_name: "Lovelace" } }

        expect(response).to redirect_to user_profile_path
        expect(user.profile.reload.full_name).to eq "Ada Lovelace"
      end

      it "re-renders the edit page when the update is invalid" do
        user = create(:user)
        sign_in_as(user)

        patch user_profile_path, params: { user_profile: { mobile_phone: "x" * 51 } }

        expect(response).to have_http_status :unprocessable_entity
      end
    end
  end
end
