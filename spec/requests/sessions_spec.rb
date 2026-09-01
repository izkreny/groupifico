require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  describe "GET /session/new" do
    context "when not signed in" do
      it "renders the sign-in page, asking for an email address and nothing else" do
        get new_session_path

        expect(response.body).to include('type="email"')
        expect(response.body).not_to include('type="password"')
      end
    end

    context "when already signed in" do
      it "redirects to the root page instead of offering to sign in again" do
        sign_in_as(create(:user))

        get new_session_path

        expect(response).to redirect_to root_path
      end
    end
  end

  describe "POST /session" do
    context "when not signed in" do
      it "enqueues the sign-in link for an address that has an account" do
        user = create(:user)

        expect { post session_path, params: { email: user.email } }
          .to have_enqueued_mail(SignInMailer, :link).with(user)

        expect(response).to redirect_to new_session_path
      end

      # The response has to match in status, body and timing, so the mail is enqueued rather than
      # delivered: a path that waits on SMTP is distinguishable however identical the page is.
      it "answers an address with no account identically, and enqueues nothing" do
        user = create(:user)
        stranger = build(:user)

        post session_path, params: { email: user.email }
        known = [ response.status, flash[:notice] ]

        expect { post session_path, params: { email: stranger.email } }
          .not_to have_enqueued_mail(SignInMailer, :link)

        expect([ response.status, flash[:notice] ]).to eq(known)
      end

      # Against the words rather than against the constant: comparing the flash to
      # `SessionsController::LINK_SENT` would prove only that one constant equals itself, and #139
      # requires this text to point a person without an account at an invitation. It is also the
      # copy the PR body flags as something `bin/ci` cannot judge, so nothing else covers it.
      it "tells a person with no account how to get one" do
        post session_path, params: { email: build(:user).email }

        expect(flash[:notice]).to include("invitation")
        expect(flash[:notice]).to match(/owner or an administrator/)
      end

      it "starts no session, because the link has not been followed yet" do
        user = create(:user)

        expect { post session_path, params: { email: user.email } }
          .not_to change(Session, :count)
      end
    end

    context "when already signed in" do
      it "redirects to the root page without enqueueing anything" do
        sign_in_as(create(:user))
        other_user = create(:user)

        expect { post session_path, params: { email: other_user.email } }
          .not_to have_enqueued_mail(SignInMailer, :link)

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
