require 'rails_helper'

RSpec.describe "Passwords", type: :request do
  describe "GET /passwords/new" do
    context "when not signed in" do
      it "renders the forgot-password page" do
        get new_password_path

        expect(response).to have_http_status :ok
      end
    end

    context "when already signed in" do
      it "still renders the forgot-password page" do
        sign_in_as(create(:user))

        get new_password_path

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "POST /passwords" do
    context "when not signed in" do
      it "emails reset instructions to a matching user and redirects to sign-in" do
        user = create(:user)

        expect { post passwords_path, params: { email: user.email } }
          .to have_enqueued_mail(PasswordsMailer, :reset).with(user)

        expect(response).to redirect_to new_session_path
      end

      it "redirects to sign-in without emailing anyone for an unknown address" do
        create(:user)
        potential_user = build(:user)

        expect { post passwords_path, params: { email: potential_user.email } }
          .not_to have_enqueued_mail(PasswordsMailer, :reset)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when already signed in" do
      it "still emails reset instructions and redirects to sign-in" do
        sign_in_as(create(:user))
        other_user = create(:user)

        expect { post passwords_path, params: { email: other_user.email } }
          .to have_enqueued_mail(PasswordsMailer, :reset).with(other_user)

        expect(response).to redirect_to new_session_path
      end
    end
  end

  describe "GET /passwords/:token/edit" do
    context "when not signed in" do
      it "renders the reset-password page for a valid token" do
        user = create(:user)

        get edit_password_path(user.password_reset_token)

        expect(response).to have_http_status :ok
      end

      it "redirects to the forgot-password page for an invalid token" do
        get edit_password_path("not-a-real-token")

        expect(response).to redirect_to new_password_path
      end
    end

    context "when already signed in" do
      it "still renders the reset-password page for a valid token" do
        sign_in_as(create(:user))
        other_user = create(:user)

        get edit_password_path(other_user.password_reset_token)

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "PATCH /passwords/:token" do
    context "when not signed in" do
      let(:user) { create(:user) }

      it "resets the password and redirects to sign-in" do
        patch password_path(user.password_reset_token), params: { password: "1234", password_confirmation: "1234" }

        expect(response).to redirect_to new_session_path
        expect(user.reload.authenticate("1234")).to eq user
      end

      it "redirects back to the reset-password page when the confirmation does not match" do
        token = user.password_reset_token

        patch password_path(token), params: { password: "1234", password_confirmation: "0000" }

        expect(response).to redirect_to edit_password_path(token)
        expect(user.reload.authenticate("1234")).to be false
      end

      it "destroys the user's existing sessions once the password resets" do
        sign_in_as(user)

        expect { patch password_path(user.password_reset_token), params: { password: "1234", password_confirmation: "1234" } }
          .to change(user.sessions, :count).to(0)
      end
    end

    context "when already signed in" do
      it "still resets another user's password and redirects to sign-in" do
        sign_in_as(create(:user))
        other_user = create(:user)

        patch password_path(other_user.password_reset_token), params: { password: "1234", password_confirmation: "1234" }

        expect(response).to redirect_to new_session_path
        expect(other_user.reload.authenticate("1234")).to eq other_user
      end
    end
  end
end
