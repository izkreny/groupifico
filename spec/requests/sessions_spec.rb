require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  describe "GET /session/new" do
    context "when not signed in" do
      it "renders the sign-in page" do
        get new_session_path

        expect(response).to have_http_status :ok
      end
    end

    context "when already signed in" do
      it "still renders the sign-in page" do
        sign_in_as(create(:user))

        get new_session_path

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "POST /session" do
    context "when not signed in" do
      it "signs in with valid credentials and redirects to the root page" do
        user = create(:user)

        post session_path, params: { email: user.email, password: user.password }

        expect(response).to redirect_to root_path
      end

      it "redirects back to sign-in with invalid credentials" do
        create(:user, password: "0000")

        post session_path, params: { email: "wrong@example.com", password: "0000" }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when already signed in" do
      it "signs in as the newly authenticated user, creating another session" do
        sign_in_as(create(:user))
        other_user = create(:user)

        expect { post session_path, params: { email: other_user.email, password: other_user.password } }
          .to change(Session, :count).by(1)

        expect(response).to redirect_to root_path
      end
    end
  end

  describe "DELETE /session" do
    context "when not signed in" do
      it "redirects to the sign-in page without destroying a session" do
        expect { delete session_path }
          .not_to change(Session, :count)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "destroys the session and redirects to the sign-in page" do
        sign_in_as(create(:user))

        expect { delete session_path }
          .to change(Session, :count).by(-1)

        expect(response).to redirect_to new_session_path
      end
    end
  end
end
