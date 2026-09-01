require 'rails_helper'

RSpec.describe "SignIns", type: :request do
  describe "GET /sign_in" do
    context "when not signed in" do
      # A company mail filter opens every link in a message before the recipient does, so this GET
      # is as likely to be a scanner as a person. Both halves matter: it renders, and it spends
      # nothing.
      it "renders the confirmation page and starts no session" do
        token = SignInToken.mint(create(:user))

        expect { get sign_in_path(token: token) }.not_to change(Session, :count)

        expect(response).to have_http_status :ok
      end

      it "leaves the link unspent, so the button still works afterwards" do
        user = create(:user)
        token = SignInToken.mint(user)

        get sign_in_path(token: token)

        expect(SignInToken.redeem!(token)).to eq(user)
      end

      # Parsed out of the rendered HTML rather than matched against the body as a string, so a
      # frontend rewrite that moves or restyles this cannot drop it silently: the address has to
      # still be somewhere a reader would see it. It is what stops a link nobody sent you being
      # indistinguishable from your own.
      it "names the account it would sign in" do
        user = create(:user)

        get sign_in_path(token: SignInToken.mint(user))

        expect(page_text(response.body)).to include(user.email)
      end

      it "refuses a request carrying no token at all" do
        get sign_in_path

        expect(response).to redirect_to new_session_path
        expect(flash[:alert]).to eq(SignInsController::INVALID_LINK)
      end

      # Refused rather than rendered without a name: a page that cannot say whose account this is
      # is the page the naming exists to replace.
      it "refuses a token that resolves to nothing" do
        get sign_in_path(token: "not-a-real-token")

        expect(response).to redirect_to new_session_path
        expect(flash[:alert]).to eq(SignInsController::INVALID_LINK)
      end
    end

    context "when already signed in" do
      it "redirects to the root page rather than offering a second account" do
        sign_in_as(create(:user))
        token = SignInToken.mint(create(:user))

        get sign_in_path(token: token)

        expect(response).to redirect_to root_path
      end
    end
  end

  describe "POST /sign_in" do
    context "when not signed in" do
      it "signs the person in and redirects to the root page" do
        user = create(:user)
        get sign_in_path(token: SignInToken.mint(user))

        expect { post sign_in_path }.to change { user.sessions.count }.by(1)

        expect(response).to redirect_to root_url
      end

      # Signed out in between, because a second attempt while still signed in is refused by the
      # already-authenticated guard instead, which would pass this example without the link ever
      # having been spent. The refusal now lands on the second GET rather than the POST: a spent
      # link resolves to nothing, so the page that would carry the button is never rendered.
      it "refuses a second use of one link" do
        token = SignInToken.mint(create(:user))
        get sign_in_path(token: token)
        post sign_in_path
        delete session_path

        expect { get sign_in_path(token: token) }.not_to change(Session, :count)

        expect(response).to redirect_to new_session_path
        expect(flash[:alert]).to eq(SignInsController::INVALID_LINK)
      end

      it "refuses a link past its window" do
        token = SignInToken.mint(create(:user))
        get sign_in_path(token: token)

        travel_to SignInToken::EXPIRES_IN.from_now + 1.second do
          expect { post sign_in_path }.not_to change(Session, :count)
        end

        expect(response).to redirect_to new_session_path
      end

      # Whether it worked or not, the token is spent from the browser's point of view. Leaving it
      # behind on the failure path would hand a second attempt to whoever gets the session next.
      # The failure is staged by expiry rather than by a bogus token, since the GET now refuses
      # anything that resolves to nothing and a bogus one never reaches the session at all.
      it "drops the token from the browser session on the failure path too" do
        get sign_in_path(token: SignInToken.mint(create(:user)))

        travel_to SignInToken::EXPIRES_IN.from_now + 1.second do
          post sign_in_path
        end

        expect(session[:sign_in_token]).to be_nil
      end

      # On the session id, because nothing the application stores in a browser session now
      # outlives sign-in for a value assertion to catch. Setting a key between requests would
      # assert nothing either way - a request spec re-reads `session` from each response.
      it "issues a fresh browser session, so one planted before sign-in does not survive it" do
        get sign_in_path(token: SignInToken.mint(create(:user)))
        planted = session.id.to_s

        post sign_in_path

        expect(session.id.to_s).not_to eq(planted)
      end
    end

    context "when already signed in" do
      it "redirects to the root page without starting another session" do
        sign_in_as(create(:user))
        SignInToken.mint(create(:user))

        expect { post sign_in_path }.not_to change(Session, :count)

        expect(response).to redirect_to root_path
      end
    end
  end
end
