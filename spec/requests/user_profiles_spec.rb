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

      it "writes the email with the name in one save" do
        user = create(:user)
        sign_in_as(user)

        patch user_profile_path, params: { user_profile: { first_name: "Ada", user_attributes: { email: "ada@example.com" } } }

        expect(response).to redirect_to user_profile_path
        expect(user.profile.reload.first_name).to eq "Ada"
        expect(user.reload.email).to eq "ada@example.com"
      end

      # The account write is skipped rather than repeated: an unchanged email writes nothing to
      # `users`, so `User`'s email-change callback never consumes the reader's outstanding links.
      it "leaves the account untouched when the email is unchanged" do
        user = create(:user)
        sign_in_as(user)
        travel 1.day

        expect { patch user_profile_path, params: { user_profile: { first_name: "Ada", user_attributes: { email: user.email } } } }
          .not_to change { user.reload.updated_at }
      end

      it "keeps the name unsaved when the email is refused" do
        user = create(:user)
        sign_in_as(user)

        patch user_profile_path, params: { user_profile: { first_name: "Ada", user_attributes: { email: "ada.example.com" } } }

        expect(response).to have_http_status :unprocessable_content
        expect(user.profile.reload.first_name).not_to eq "Ada"
        expect(user.reload.email).not_to eq "ada.example.com"
      end

      # The account written is always the one the profile belongs to, whatever the request names.
      it "writes the reader's own email when the params name another account" do
        user = create(:user)
        other = create(:user, email: "other@example.com")
        sign_in_as(user)

        patch user_profile_path, params: { user_profile: { user_attributes: { id: other.id, email: "taken@example.com" } } }

        expect(other.reload.email).to eq "other@example.com"
        expect(user.reload.email).to eq "taken@example.com"
      end

      it "re-renders the edit page when the update is invalid" do
        user = create(:user)
        sign_in_as(user)

        patch user_profile_path, params: { user_profile: { mobile_phone: "x" * 51 } }

        expect(response).to have_http_status :unprocessable_content
      end
    end
  end
end
