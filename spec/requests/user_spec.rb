require 'rails_helper'

RSpec.describe "User", type: :request do
  describe "GET /user" do
    context "when not signed in" do
      it "redirects to the login page" do
        get user_path

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows user page" do
        sign_in_as(create(:user))

        get user_path

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "GET /user/edit" do
    context "when not signed in" do
      it "redirects to the login page" do
        get edit_user_path

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows edit user page" do
        sign_in_as(create(:user))

        get edit_user_path

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "PATCH /user" do
    context "when not signed in" do
      it "redirects to the login page" do
        patch user_path, params: { user: { email: "changed@example.com" } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "updates the user" do
        user = create(:user)
        sign_in_as(user)

        patch user_path, params: { user: { email: "changed@example.com" } }

        expect(response).to redirect_to user_path
        expect(user.reload.email).to eq "changed@example.com"
      end
    end
  end

  describe "DELETE /user" do
    context "when not signed in" do
      it "redirects to the login page" do
        create(:user)

        expect { delete user_path }
          .not_to change(User, :count)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "destroys the user" do
        sign_in_as(create(:user))

        expect { delete user_path }
          .to change(User, :count).by(-1)

        # Known-wrong target: destroying the user destroys their session too,
        # so `user_path` can never render for them. #179 fixes the controller.
        expect(response).to redirect_to user_path
      end
    end
  end
end
