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

      it "carries the destination the link names on its button" do
        get sign_in_path(token: SignInToken.mint(create(:user)), return_to: "/groups/1/events/2")

        expect(Nokogiri::HTML(response.body).at_css("form input[type=hidden][name=return_to]")["value"]).to eq "/groups/1/events/2"
      end

      # #430 AC2: a nested `return_to[a]=b` arrives as parameters rather than a string, and must land
      # on the root like any other value that is not a path, never answer 500.
      it "renders a link whose destination is not a string, carrying none on its button" do
        get sign_in_path(token: SignInToken.mint(create(:user)), return_to: { a: "b" })

        expect(Nokogiri::HTML(response.body).at_css("form input[type=hidden][name=return_to]")["value"]).to be_blank
      end

      # #430 AC1: an expired link sends the member back to ask for another, and that one has to carry
      # the destination the expired one did.
      it "keeps the destination on the form it refuses an expired link to" do
        token = SignInToken.mint(create(:user))

        travel_to SignInToken::EXPIRES_IN.from_now + 1.second do
          get sign_in_path(token:, return_to: "/groups/1/events/2")
        end

        expect(response).to redirect_to new_session_path(return_to: "/groups/1/events/2")
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

      # #430 AC1.
      it "signs the person in and lands on the destination the link carried" do
        get sign_in_path(token: SignInToken.mint(create(:user)))

        post sign_in_path, params: { return_to: "/groups/1/events/2" }

        expect(response).to redirect_to "/groups/1/events/2"
      end

      # #430 AC2, the open-redirect guard. Posted straight at the redemption rather than through the
      # form, because the link's query string and the button's hidden field are both anybody's to
      # write, so this is the hop the guard has to hold at. The backslash form is one browsers read
      # as `//`.
      it "lands on the root page for a URL on another host" do
        get sign_in_path(token: SignInToken.mint(create(:user)))

        post sign_in_path, params: { return_to: "https://other.example/x" }

        expect(response).to redirect_to root_url
      end

      it "lands on the root page for a protocol-relative URL" do
        get sign_in_path(token: SignInToken.mint(create(:user)))

        post sign_in_path, params: { return_to: "//other.example" }

        expect(response).to redirect_to root_url
      end

      it "lands on the root page for a path a browser reads as another host" do
        get sign_in_path(token: SignInToken.mint(create(:user)))

        post sign_in_path, params: { return_to: "/\\other.example" }

        expect(response).to redirect_to root_url
      end

      it "sets the session cookie HttpOnly and SameSite=Lax" do
        get sign_in_path(token: SignInToken.mint(create(:user)))

        post sign_in_path

        session_cookie = Array(response.headers["set-cookie"]).join("\n").lines.grep(/\Asession_id=/).sole
        expect(session_cookie).to match(/;\s*httponly/i).and match(/;\s*samesite=lax/i)
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
      it "keeps the destination on the form when the link expires before the button is pressed" do
        get sign_in_path(token: SignInToken.mint(create(:user)))

        travel_to SignInToken::EXPIRES_IN.from_now + 1.second do
          post sign_in_path, params: { return_to: "/groups/1/events/2" }
        end

        expect(response).to redirect_to new_session_path(return_to: "/groups/1/events/2")
      end

      it "keeps the destination on the form when the rate limit refuses a redemption" do
        10.times { post sign_in_path }

        post sign_in_path, params: { return_to: "/groups/1/events/2" }

        expect(response).to redirect_to new_session_path(return_to: "/groups/1/events/2")
        expect(flash[:alert]).to eq("Try again later.")
      end

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
