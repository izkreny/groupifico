require "rails_helper"

RSpec.describe "JoinRequests::SignInLinks", type: :request do
  describe "POST /join/sign_in_link" do
    context "when not signed in" do
      it "creates the user for an unknown address and mails it a sign-in link back to the join page" do
        token = JoinLink.mint(create(:group))

        expect { post join_request_sign_in_link_path, params: { token:, user: { email: "visitor@example.com" } } }
          .to have_enqueued_mail(SignInMailer, :link)
          .with(an_object_having_attributes(email: "visitor@example.com"), return_to: "/join/new?token=#{token}")

        expect(User.where(email: "visitor@example.com")).to exist
        expect(response).to redirect_to join_request_sign_in_link_path
      end

      it "mails an existing user's link without creating anybody" do
        user  = create(:user, email: "known@example.com")
        token = JoinLink.mint(create(:group))
        users = User.count

        expect { post join_request_sign_in_link_path, params: { token:, user: { email: "Known@Example.com " } } }
          .to have_enqueued_mail(SignInMailer, :link).with(user, return_to: "/join/new?token=#{token}")

        expect(User.count).to eq users
        expect(response).to redirect_to join_request_sign_in_link_path
      end

      # WHY: AC3, since a uniqueness error or any other difference would tell whoever holds the link which addresses already have accounts, here or in another group.
      it "answers an unknown address, an existing user and an existing member identically" do
        token = JoinLink.mint(create(:group))
        create(:user, email: "user@example.com")
        create(:member, user: create(:user, email: "member@example.com"))

        answers = %w[ stranger@example.com user@example.com member@example.com ].map do |email|
          post join_request_sign_in_link_path, params: { token:, user: { email: } }
          [ response.status, response.location, flash.to_h ]
        end

        expect(answers.uniq).to eq [ [ 302, join_request_sign_in_link_url, {} ] ]
      end

      # WHY: the losing side of two requests racing for one new address, whose `find_by` missed the row the other then created; the row is inserted raw and differently cased because that is the one way to reach the same state without a second thread, and the winner is what mails.
      it "answers the request that lost a race for a new address like any other, mailing nothing" do
        token = JoinLink.mint(create(:group))
        User.connection.execute("INSERT INTO users (email, created_at, updated_at) VALUES ('Racer@Example.com', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")

        expect { post join_request_sign_in_link_path, params: { token:, user: { email: "racer@example.com" } } }
          .not_to have_enqueued_mail(SignInMailer, :link)

        expect(response).to redirect_to join_request_sign_in_link_path
      end

      it "refuses a blank address with the error on the field and mails nothing" do
        token = JoinLink.mint(create(:group))

        expect { post join_request_sign_in_link_path, params: { token:, user: { email: "" } } }
          .not_to have_enqueued_mail(SignInMailer, :link)

        expect(response).to have_http_status :unprocessable_content
        expect(response.body).to include('id="user_email_error"', "Email can&#39;t be blank")
      end

      it "refuses a malformed address with the error on the field and creates nobody" do
        token = JoinLink.mint(create(:group))

        expect { post join_request_sign_in_link_path, params: { token:, user: { email: "not-an-address" } } }
          .not_to change(User, :count)

        expect(response).to have_http_status :unprocessable_content
        expect(response.body).to include('id="user_email_error"', "Email is invalid")
      end

      # WHY: AC5, since a link turned off after its page was opened must not still mail or create anybody.
      it "answers 404 for a link turned off before the form was sent, mailing nothing and creating nobody" do
        group = create(:group)
        token = JoinLink.mint(group)
        group.join_link.destroy!

        expect { post join_request_sign_in_link_path, params: { token:, user: { email: "visitor@example.com" } } }
          .not_to have_enqueued_mail(SignInMailer, :link)

        expect(response).to have_http_status :not_found
        expect(User.where(email: "visitor@example.com")).not_to exist
      end

      # WHY: AC6. Each limit is driven to its own threshold on its own key with the other kept clear, and the last accepted submission is asserted as well as the first refused one, for the reasons `spec/requests/sign_ups_spec.rb` gives.
      # WHY: spelled three ways, because the key must normalise as `User` does or one inbox gets a bucket per spelling.
      it "accepts three submissions for one address and refuses the fourth, however the IP or the spelling moves" do
        token = JoinLink.mint(create(:group))
        post join_request_sign_in_link_path, params: { token:, user: { email: "Flooded@Example.com" } }, headers: { "REMOTE_ADDR" => "10.0.0.1" }
        post join_request_sign_in_link_path, params: { token:, user: { email: "flooded@example.com " } }, headers: { "REMOTE_ADDR" => "10.0.0.2" }
        post join_request_sign_in_link_path, params: { token:, user: { email: "flooded@example.com" } }, headers: { "REMOTE_ADDR" => "10.0.0.3" }

        expect(response).to redirect_to join_request_sign_in_link_path

        post join_request_sign_in_link_path, params: { token:, user: { email: "flooded@example.com" } }, headers: { "REMOTE_ADDR" => "10.0.0.4" }

        expect(response).to redirect_to new_join_request_path(token:)
        expect(flash[:alert]).to eq("Try again later.")
      end

      it "keeps refusing the address while its third link could still be used" do
        token = JoinLink.mint(create(:group))
        3.times { post join_request_sign_in_link_path, params: { token:, user: { email: "patient@example.com" } } }

        travel_to SignInToken::EXPIRES_IN.from_now - 1.second do
          post join_request_sign_in_link_path, params: { token:, user: { email: "patient@example.com" } }
        end

        expect(flash[:alert]).to eq("Try again later.")
      end

      it "counts the address afresh once the link's window has passed" do
        token = JoinLink.mint(create(:group))
        3.times { post join_request_sign_in_link_path, params: { token:, user: { email: "patient@example.com" } } }

        travel_to SignInToken::EXPIRES_IN.from_now + 1.second do
          post join_request_sign_in_link_path, params: { token:, user: { email: "patient@example.com" } }
        end

        expect(response).to redirect_to join_request_sign_in_link_path
      end

      it "accepts ten submissions from one IP and refuses the eleventh, however the address moves" do
        token = JoinLink.mint(create(:group))
        10.times do |n|
          post join_request_sign_in_link_path, params: { token:, user: { email: "walker-#{n}@example.com" } }, headers: { "REMOTE_ADDR" => "10.1.0.1" }
        end

        expect(response).to redirect_to join_request_sign_in_link_path

        post join_request_sign_in_link_path, params: { token:, user: { email: "walker-last@example.com" } }, headers: { "REMOTE_ADDR" => "10.1.0.1" }

        expect(response).to redirect_to new_join_request_path(token:)
        expect(flash[:alert]).to eq("Try again later.")
      end

      # WHY: a blank address gives the address limit a blank key, which `rate_limit` would make one counter every such request shares; four from four IPs stay inside the limit, so the fourth is refused on its own merits.
      it "buckets a blank-address submission by IP rather than into one shared counter" do
        token = JoinLink.mint(create(:group))
        post join_request_sign_in_link_path, params: { token:, user: { email: "" } }, headers: { "REMOTE_ADDR" => "10.2.0.1" }
        post join_request_sign_in_link_path, params: { token:, user: { email: "" } }, headers: { "REMOTE_ADDR" => "10.2.0.2" }
        post join_request_sign_in_link_path, params: { token:, user: { email: "" } }, headers: { "REMOTE_ADDR" => "10.2.0.3" }
        post join_request_sign_in_link_path, params: { token:, user: { email: "" } }, headers: { "REMOTE_ADDR" => "10.2.0.4" }

        expect(response).to have_http_status :unprocessable_content
      end

      it "answers 400 for a body whose user is not a set of fields" do
        token = JoinLink.mint(create(:group))

        post join_request_sign_in_link_path, params: { token:, user: "x" }

        expect(response).to have_http_status :bad_request
      end

      it "starts no session, because the link has not been followed yet" do
        token = JoinLink.mint(create(:group))

        expect { post join_request_sign_in_link_path, params: { token:, user: { email: "visitor@example.com" } } }
          .not_to change(Session, :count)
      end
    end

    context "when signed in" do
      it "redirects to the root page and mails nothing" do
        sign_in_as create(:user)
        token = JoinLink.mint(create(:group))

        expect { post join_request_sign_in_link_path, params: { token:, user: { email: "visitor@example.com" } } }
          .not_to have_enqueued_mail(SignInMailer, :link)

        expect(response).to redirect_to root_path
      end
    end
  end

  describe "GET /join/sign_in_link" do
    context "when not signed in" do
      it "tells the visitor to check their inbox" do
        get join_request_sign_in_link_path

        expect(page_text(response.body)).to include("Check your inbox", "A sign-in link is on its way.")
      end
    end

    context "when signed in" do
      it "redirects to the root page" do
        sign_in_as create(:user)

        get join_request_sign_in_link_path

        expect(response).to redirect_to root_path
      end
    end
  end
end
