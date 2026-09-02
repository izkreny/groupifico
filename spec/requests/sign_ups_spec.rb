require 'rails_helper'

RSpec.describe "SignUps", type: :request do
  describe "GET /sign_up/new" do
    context "when not signed in" do
      it "renders the form, asking for a group name and an email address" do
        get new_sign_up_path

        expect(response.body).to include('name="sign_up[group_name]"')
        expect(response.body).to include('name="sign_up[email]"')
      end
    end

    context "when already signed in" do
      it "redirects to the root page rather than offering a second account" do
        sign_in_as(create(:user))

        get new_sign_up_path

        expect(response).to redirect_to root_path
      end
    end
  end

  describe "POST /sign_up" do
    context "when not signed in" do
      # The submission writes nothing at all: the row comes into existence in the job, which is
      # the cleanest form of answering identically whether or not the address has an account.
      it "records nothing and enqueues the link" do
        expect { post sign_up_path, params: { sign_up: { email: "starter@example.com", group_name: "Chamber Choir" } } }
          .to have_enqueued_mail(SignUpMailer, :link).with("starter@example.com", "Chamber Choir")

        expect(SignUp.where(email: "starter@example.com")).not_to exist
        expect(response).to redirect_to new_sign_up_path
      end

      # The whole reason nothing is written before the address is proven. A duplicate must not be
      # detectable, so status, location and copy all have to match.
      it "answers an address that already has an account identically" do
        post sign_up_path, params: { sign_up: { email: "stranger@example.com", group_name: "Chamber Choir" } }
        unknown = [ response.status, response.location, flash[:notice] ]

        create(:user, email: "starter@example.com")
        post sign_up_path, params: { sign_up: { email: "starter@example.com", group_name: "Chamber Choir" } }

        expect([ response.status, response.location, flash[:notice] ]).to eq(unknown)
      end

      it "creates no user and no group" do
        post sign_up_path, params: { sign_up: { email: "starter@example.com", group_name: "Chamber Choir" } }

        expect(User.where(email: "starter@example.com")).not_to exist
        expect(Group.where(name: "Chamber Choir")).not_to exist
      end

      # Validated in the request rather than in the job, because the row is written there: an
      # invalid submission that reached the queue would raise in the background after this person
      # had been told to check their inbox.
      it "re-renders the form and enqueues nothing when the group has no name" do
        expect { post sign_up_path, params: { sign_up: { email: "starter@example.com", group_name: "" } } }
          .not_to have_enqueued_mail(SignUpMailer, :link)

        expect(response).to have_http_status :unprocessable_content
      end

      it "re-renders the form when the address is not one User would accept" do
        post sign_up_path, params: { sign_up: { email: "not-an-address", group_name: "Chamber Choir" } }

        expect(response).to have_http_status :unprocessable_content
      end

      # Each limit driven to its own threshold on its own key, while the other stays clear: these
      # three arrive from three different IPs, and the IP example's addresses are all different,
      # so neither example can be passing on the other's limit.
      #
      # Both assert the last accepted submission as well as the first refused one, so the
      # threshold is pinned rather than merely exceeded - without the accepted half, mutating
      # `to:` down to 1 would leave them green.
      it "accepts three submissions for one address and refuses the fourth, however the IP moves" do
        post sign_up_path, params: { sign_up: { email: "flooded@example.com", group_name: "Choir" } }, headers: { "REMOTE_ADDR" => "10.0.0.1" }
        post sign_up_path, params: { sign_up: { email: "flooded@example.com", group_name: "Choir" } }, headers: { "REMOTE_ADDR" => "10.0.0.2" }
        post sign_up_path, params: { sign_up: { email: "flooded@example.com", group_name: "Choir" } }, headers: { "REMOTE_ADDR" => "10.0.0.3" }

        expect(flash[:notice]).to eq(SignUpsController::LINK_SENT)

        post sign_up_path, params: { sign_up: { email: "flooded@example.com", group_name: "Choir" } }, headers: { "REMOTE_ADDR" => "10.0.0.4" }

        expect(response).to redirect_to new_sign_up_path
        expect(flash[:alert]).to eq("Try again later.")
      end

      # The window is the link's own lifetime, and this is the end of it that pins that: any
      # shorter interval - `3.minutes`, say - would have reset the count by now and accepted this
      # submission. The pair below covers the other end.
      it "keeps refusing the address while its third link could still be used" do
        post sign_up_path, params: { sign_up: { email: "patient@example.com", group_name: "Choir" } }
        post sign_up_path, params: { sign_up: { email: "patient@example.com", group_name: "Choir" } }
        post sign_up_path, params: { sign_up: { email: "patient@example.com", group_name: "Choir" } }

        travel_to SignUp::EXPIRES_IN.from_now - 1.second do
          post sign_up_path, params: { sign_up: { email: "patient@example.com", group_name: "Choir" } }
        end

        expect(flash[:alert]).to eq("Try again later.")
      end

      # And the other end, which is what keeps a person whose first three links all expired from
      # being locked out of their own sign-up.
      it "counts the address afresh once the link's window has passed" do
        post sign_up_path, params: { sign_up: { email: "patient@example.com", group_name: "Choir" } }
        post sign_up_path, params: { sign_up: { email: "patient@example.com", group_name: "Choir" } }
        post sign_up_path, params: { sign_up: { email: "patient@example.com", group_name: "Choir" } }

        travel_to SignUp::EXPIRES_IN.from_now + 1.second do
          post sign_up_path, params: { sign_up: { email: "patient@example.com", group_name: "Choir" } }
        end

        expect(flash[:notice]).to eq(SignUpsController::LINK_SENT)
      end

      it "accepts ten submissions from one IP and refuses the eleventh, however the address moves" do
        10.times do |n|
          post sign_up_path, params: { sign_up: { email: "walker-#{n}@example.com", group_name: "Choir" } },
            headers: { "REMOTE_ADDR" => "10.1.0.1" }
        end

        expect(flash[:notice]).to eq(SignUpsController::LINK_SENT)

        post sign_up_path, params: { sign_up: { email: "walker-last@example.com", group_name: "Choir" } },
          headers: { "REMOTE_ADDR" => "10.1.0.1" }

        expect(response).to redirect_to new_sign_up_path
        expect(flash[:alert]).to eq("Try again later.")
      end

      # The finding's own scenario: a POST with no `sign_up` key gives the address limit a blank
      # key, and Rails' `[..., name, by].compact.join(":")` makes that a valid bucket every such
      # request would share. Four of them from four IPs stay inside the address limit's own
      # threshold, so the fourth is refused on its own merits rather than by a shared counter.
      it "buckets an address-less submission by IP rather than into one shared counter" do
        post sign_up_path, params: { group_name: "Choir" }, headers: { "REMOTE_ADDR" => "10.2.0.1" }
        post sign_up_path, params: { group_name: "Choir" }, headers: { "REMOTE_ADDR" => "10.2.0.2" }
        post sign_up_path, params: { group_name: "Choir" }, headers: { "REMOTE_ADDR" => "10.2.0.3" }
        post sign_up_path, params: { group_name: "Choir" }, headers: { "REMOTE_ADDR" => "10.2.0.4" }

        expect(response).to have_http_status :bad_request
      end

      it "starts no session, because the link has not been followed yet" do
        expect { post sign_up_path, params: { sign_up: { email: "starter@example.com", group_name: "Chamber Choir" } } }
          .not_to change(Session, :count)
      end
    end

    context "when already signed in" do
      it "redirects to the root page without enqueueing anything" do
        sign_in_as(create(:user))

        expect { post sign_up_path, params: { sign_up: { email: "starter@example.com", group_name: "Chamber Choir" } } }
          .not_to have_enqueued_mail(SignUpMailer, :link)

        expect(response).to redirect_to root_path
      end
    end
  end
end
