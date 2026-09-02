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

      # Both limits, each driven past its threshold on its own key while the other stays clear:
      # eleven addresses from one IP can only trip the IP limit, and one address from eleven IPs
      # can only trip the address one. Rails' memory store is shared across examples in a run, so
      # each uses a key of its own.
      it "refuses an eleventh submission from one address, however the IP moves" do
        11.times do |n|
          post sign_up_path, params: { sign_up: { email: "flooded@example.com", group_name: "Choir" } },
            headers: { "REMOTE_ADDR" => "10.0.0.#{n}" }
        end

        expect(response).to redirect_to new_sign_up_path
        expect(flash[:alert]).to eq("Try again later.")
      end

      it "refuses an eleventh submission from one IP, however the address moves" do
        11.times do |n|
          post sign_up_path, params: { sign_up: { email: "walker-#{n}@example.com", group_name: "Choir" } },
            headers: { "REMOTE_ADDR" => "10.1.0.1" }
        end

        expect(response).to redirect_to new_sign_up_path
        expect(flash[:alert]).to eq("Try again later.")
      end

      # The finding's own scenario: a POST with no `sign_up` key gives the address limit a blank
      # key, and Rails' `[..., name, by].compact.join(":")` makes that a valid bucket every such
      # request would share. Eleven of them from eleven IPs each get their own refusal rather than
      # one shared counter's.
      it "buckets an address-less submission by IP rather than into one shared counter" do
        11.times do |n|
          post sign_up_path, params: { group_name: "Choir" }, headers: { "REMOTE_ADDR" => "10.2.0.#{n}" }
        end

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
