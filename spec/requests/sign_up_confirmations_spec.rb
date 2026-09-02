require 'rails_helper'

RSpec.describe "SignUpConfirmations", type: :request do
  describe "GET /sign_up_confirmation" do
    context "when not signed in" do
      # A mail filter opens every link in a message before the recipient does, so this GET is as
      # likely to be a scanner as a person. Both halves matter: it renders, and it creates nothing.
      it "renders the confirmation page and creates nothing" do
        token = SignUp.mint(email: "starter@example.com", group_name: "Chamber Choir")

        get sign_up_confirmation_path(token: token)

        expect(response).to have_http_status :ok
        expect(User.where(email: "starter@example.com")).not_to exist
        expect(Group.where(name: "Chamber Choir")).not_to exist
      end

      it "leaves the link unspent, so the button still works afterwards" do
        token = SignUp.mint(email: "starter@example.com", group_name: "Chamber Choir")

        get sign_up_confirmation_path(token: token)

        expect(SignUp.redeem!(token).group.name).to eq("Chamber Choir")
      end

      # Parsed out of the rendered HTML rather than matched as a string, so a frontend rewrite
      # cannot drop either value silently. Naming both is what stops a link nobody sent you being
      # indistinguishable from your own.
      it "names both the address and the group it would create" do
        get sign_up_confirmation_path(token: SignUp.mint(email: "starter@example.com", group_name: "Chamber Choir"))

        expect(page_text(response.body)).to include("starter@example.com").and include("Chamber Choir")
      end

      it "refuses a request carrying no token at all" do
        get sign_up_confirmation_path

        expect(response).to redirect_to new_sign_up_path
        expect(flash[:alert]).to eq(SignUpConfirmationsController::INVALID_LINK)
      end

      it "refuses a token that resolves to nothing" do
        get sign_up_confirmation_path(token: "not-a-real-token")

        expect(response).to redirect_to new_sign_up_path
        expect(flash[:alert]).to eq(SignUpConfirmationsController::INVALID_LINK)
      end

      # One browser can hold an outstanding sign-in link and an outstanding sign-up link at once,
      # and the two must not overwrite each other's place in the session.
      it "holds its token separately from an outstanding sign-in link" do
        user = create(:user, email: "member@example.com")
        get sign_in_path(token: SignInToken.mint(user))

        get sign_up_confirmation_path(token: SignUp.mint(email: "starter@example.com", group_name: "Chamber Choir"))

        expect(session[:sign_in_token]).to be_present
        expect(session[:sign_up]).to be_present
      end
    end

    context "when already signed in" do
      it "redirects to the root page rather than offering a second account" do
        sign_in_as(create(:user))

        get sign_up_confirmation_path(token: SignUp.mint(email: "starter@example.com", group_name: "Chamber Choir"))

        expect(response).to redirect_to root_path
      end
    end
  end

  describe "POST /sign_up_confirmation" do
    context "when not signed in" do
      it "creates the user, the group and the owner membership, and signs them in" do
        token = SignUp.mint(email: "starter@example.com", group_name: "Chamber Choir")
        get sign_up_confirmation_path(token: token)

        expect { post sign_up_confirmation_path }.to change(Session, :count).by(1)

        expect(response).to redirect_to group_url(Group.find_by!(name: "Chamber Choir"))
      end

      # The owner membership is what makes the landing page reachable at all: without it
      # `GroupPolicy` answers the redirect with a 404, so following it proves the membership as
      # well as the redirect target.
      it "lands the new owner on a group page they are allowed to see" do
        get sign_up_confirmation_path(token: SignUp.mint(email: "starter@example.com", group_name: "Chamber Choir"))
        post sign_up_confirmation_path

        follow_redirect!

        expect(response).to have_http_status :ok
      end

      # Signed out in between, because a second attempt while still signed in is refused by the
      # already-authenticated guard instead. The refusal lands on the second GET: a spent link
      # resolves to nothing, so the page carrying the button is never rendered again.
      it "refuses a second use of one link" do
        token = SignUp.mint(email: "starter@example.com", group_name: "Chamber Choir")
        get sign_up_confirmation_path(token: token)
        post sign_up_confirmation_path
        delete session_path

        expect { get sign_up_confirmation_path(token: token) }.not_to change(Group, :count)

        expect(response).to redirect_to new_sign_up_path
        expect(flash[:alert]).to eq(SignUpConfirmationsController::INVALID_LINK)
      end

      it "refuses a link past its window, leaving no user and no group" do
        get sign_up_confirmation_path(token: SignUp.mint(email: "starter@example.com", group_name: "Chamber Choir"))

        travel_to SignUp::EXPIRES_IN.from_now + 1.second do
          post sign_up_confirmation_path
        end

        expect(response).to redirect_to new_sign_up_path
        expect(User.where(email: "starter@example.com")).not_to exist
        expect(Group.where(name: "Chamber Choir")).not_to exist
      end

      # Whether it worked or not, the token is spent from the browser's point of view. Leaving it
      # behind on the failure path would hand a second attempt to whoever gets the session next.
      it "drops the token from the browser session on the failure path too" do
        get sign_up_confirmation_path(token: SignUp.mint(email: "starter@example.com", group_name: "Chamber Choir"))

        travel_to SignUp::EXPIRES_IN.from_now + 1.second do
          post sign_up_confirmation_path
        end

        expect(session[:sign_up]).to be_nil
      end

      it "issues a fresh browser session, so one planted before sign-up does not survive it" do
        get sign_up_confirmation_path(token: SignUp.mint(email: "starter@example.com", group_name: "Chamber Choir"))
        planted = session.id.to_s

        post sign_up_confirmation_path

        expect(session.id.to_s).not_to eq(planted)
      end

      it "gives an existing account its group without a second account" do
        create(:user, email: "starter@example.com")
        get sign_up_confirmation_path(token: SignUp.mint(email: "starter@example.com", group_name: "Chamber Choir"))

        expect { post sign_up_confirmation_path }.not_to change(User, :count)

        expect(response).to redirect_to group_url(Group.find_by!(name: "Chamber Choir"))
      end
    end

    context "when already signed in" do
      it "redirects to the root page without creating a group" do
        sign_in_as(create(:user))
        SignUp.mint(email: "starter@example.com", group_name: "Chamber Choir")

        expect { post sign_up_confirmation_path }.not_to change(Group, :count)

        expect(response).to redirect_to root_path
      end
    end
  end
end
