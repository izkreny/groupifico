require 'rails_helper'

RSpec.describe "JoinRequests", type: :request do
  describe "GET /join/new" do
    context "when not signed in" do
      it "names the group a live link belongs to" do
        token = JoinLink.mint(create(:group, name: "Riverside Choir"))

        get new_join_request_path(token:)

        expect(page_text(response.body)).to include("Riverside Choir")
      end

      it "asks for a first name, a last name, an email and a mobile phone" do
        token = JoinLink.mint(create(:group))

        get new_join_request_path(token:)

        form = Nokogiri::HTML(response.body).at_css("form[action='#{join_request_path}']")
        expect(form.css("input").map { it["name"] }).to include("join_request[first_name]", "join_request[last_name]", "join_request[email]", "join_request[mobile_phone]")
      end

      # WHY: #445 AC2, since turning the link off is what an owner does to stop it working.
      it "answers 404 for a link that was turned off" do
        group = create(:group)
        token = JoinLink.mint(group)
        group.join_link.destroy!

        get new_join_request_path(token:)

        expect(response).to have_http_status :not_found
      end

      # WHY: #445 AC3, since regenerating retires the link that travelled too far.
      it "answers 404 for a link the group has since regenerated" do
        group = create(:group)
        token = JoinLink.mint(group)
        JoinLink.mint(group)

        get new_join_request_path(token:)

        expect(response).to have_http_status :not_found
      end

      it "answers 404 for a token never minted" do
        JoinLink.mint(create(:group))

        get new_join_request_path(token: "never-minted")

        expect(response).to have_http_status :not_found
      end

      it "answers 404 for a request carrying no token at all" do
        JoinLink.mint(create(:group))

        get new_join_request_path

        expect(response).to have_http_status :not_found
      end

      it "answers 404 for a token sent as a hash" do
        JoinLink.mint(create(:group))

        get new_join_request_path, params: { token: { x: "1" } }

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in" do
      it "names the group a live link belongs to" do
        sign_in_as create(:user)
        token = JoinLink.mint(create(:group, name: "Riverside Choir"))

        get new_join_request_path(token:)

        expect(page_text(response.body)).to include("Riverside Choir")
      end

      it "answers 404 for a link that was turned off" do
        sign_in_as create(:user)
        group = create(:group)
        token = JoinLink.mint(group)
        group.join_link.destroy!

        get new_join_request_path(token:)

        expect(response).to have_http_status :not_found
      end
    end
  end

  describe "POST /join" do
    context "when not signed in" do
      it "enqueues the confirmation link with the submitted details and lands on the check-your-email page" do
        group = create(:group)
        get new_join_request_path(token: JoinLink.mint(group))

        expect { post join_request_path, params: { join_request: details } }
          .to have_enqueued_mail(JoinRequestMailer, :link).with(group.join_link.id, email: "ana@example.com", first_name: "Ana", last_name: "Kovač", mobile_phone: "+385 91 123 4567")

        expect(response).to redirect_to join_request_path
      end

      # WHY: the row is written in the job, so nothing exists before the address is proven, and nothing at all joins the group (#446).
      it "writes no request, user, member or profile" do
        get new_join_request_path(token: JoinLink.mint(create(:group)))

        expect { post join_request_path, params: { join_request: details } }
          .not_to change { [ JoinRequest.count, User.count, Member.count, UserProfile.count ] }
      end

      it "starts no session, because the link has not been followed yet" do
        get new_join_request_path(token: JoinLink.mint(create(:group)))

        expect { post join_request_path, params: { join_request: details } }.not_to change(Session, :count)
      end

      # WHY: #446 AC3, so the page cannot be used to learn whether an address has an account; one address both times keeps the copy comparable word for word.
      it "answers an address a user already holds exactly as an unknown one" do
        get new_join_request_path(token: JoinLink.mint(create(:group)))
        post join_request_path, params: { join_request: details }
        follow_redirect!
        unknown = [ response.status, page_text(response.body) ]

        create(:user, email: "ana@example.com")
        post join_request_path, params: { join_request: details }
        follow_redirect!

        expect([ response.status, page_text(response.body) ]).to eq(unknown)
      end

      it "answers an address a member of the group already holds exactly as an unknown one" do
        group = create(:group)
        get new_join_request_path(token: JoinLink.mint(group))
        post join_request_path, params: { join_request: details }
        follow_redirect!
        unknown = [ response.status, page_text(response.body) ]

        create(:member, group:, user: create(:user, email: "ana@example.com"))
        post join_request_path, params: { join_request: details }
        follow_redirect!

        expect([ response.status, page_text(response.body) ]).to eq(unknown)
      end

      it "refuses missing details with an error on each field and enqueues nothing" do
        get new_join_request_path(token: JoinLink.mint(create(:group)))

        expect { post join_request_path, params: { join_request: { email: "", first_name: "", last_name: "", mobile_phone: "" } } }
          .not_to have_enqueued_mail(JoinRequestMailer, :link)

        expect(response).to have_http_status :unprocessable_content
        expect(field_errors(response.body)).to include(
          "join_request_first_name" => "First name can't be blank", "join_request_last_name" => "Last name can't be blank",
          "join_request_email" => a_string_including("Email can't be blank"), "join_request_mobile_phone" => a_string_including("Mobile phone can't be blank"))
      end

      it "refuses an email and a mobile phone of the wrong shape with an error on each" do
        get new_join_request_path(token: JoinLink.mint(create(:group)))

        post join_request_path, params: { join_request: details.merge(email: "not-an-address", mobile_phone: "call me") }

        expect(response).to have_http_status :unprocessable_content
        expect(field_errors(response.body)).to eq("join_request_email" => "Email is invalid", "join_request_mobile_phone" => "Mobile phone is invalid")
      end

      # WHY: #446 AC5, since a link turned off while the form was open must stop working on the submission too, not only on the page.
      it "answers 404 for a link turned off after the form opened, and enqueues nothing" do
        group = create(:group)
        get new_join_request_path(token: JoinLink.mint(group))
        group.join_link.destroy!

        expect { post join_request_path, params: { join_request: details } }.not_to have_enqueued_mail(JoinRequestMailer, :link)

        expect(response).to have_http_status :not_found
      end

      it "answers 404 for a link regenerated after the form opened" do
        group = create(:group)
        get new_join_request_path(token: JoinLink.mint(group))
        JoinLink.mint(group)

        post join_request_path, params: { join_request: details }

        expect(response).to have_http_status :not_found
      end

      it "answers 404 when no join link was opened in this browser" do
        JoinLink.mint(create(:group))

        post join_request_path, params: { join_request: details }

        expect(response).to have_http_status :not_found
      end

      # WHY: sign-up's limits, pinned the way `spec/requests/sign_ups_spec.rb` pins them: the last accepted submission as well as the first refused, each limit on its own key while the other stays clear.
      it "accepts three submissions for one address and refuses the fourth, however the IP moves" do
        token = JoinLink.mint(create(:group))
        get new_join_request_path(token:)
        post join_request_path, params: { join_request: details }, headers: { "REMOTE_ADDR" => "10.0.0.1" }
        post join_request_path, params: { join_request: details }, headers: { "REMOTE_ADDR" => "10.0.0.2" }
        post join_request_path, params: { join_request: details }, headers: { "REMOTE_ADDR" => "10.0.0.3" }

        expect(response).to redirect_to join_request_path

        post join_request_path, params: { join_request: details }, headers: { "REMOTE_ADDR" => "10.0.0.4" }

        expect(response).to redirect_to new_join_request_path(token:)
        expect(flash[:alert]).to eq("Try again later.")
      end

      it "keeps refusing the address while its third link could still be used" do
        get new_join_request_path(token: JoinLink.mint(create(:group)))
        3.times { post join_request_path, params: { join_request: details } }

        travel_to JoinRequest::EXPIRES_IN.from_now - 1.second do
          post join_request_path, params: { join_request: details }
        end

        expect(flash[:alert]).to eq("Try again later.")
      end

      it "counts the address afresh once the link's window has passed" do
        get new_join_request_path(token: JoinLink.mint(create(:group)))
        3.times { post join_request_path, params: { join_request: details } }

        travel_to JoinRequest::EXPIRES_IN.from_now + 1.second do
          post join_request_path, params: { join_request: details }
        end

        expect(response).to redirect_to join_request_path
      end

      it "accepts ten submissions from one IP and refuses the eleventh, however the address moves" do
        token = JoinLink.mint(create(:group))
        get new_join_request_path(token:)
        10.times do |n|
          post join_request_path, params: { join_request: details.merge(email: "walker-#{n}@example.com") }, headers: { "REMOTE_ADDR" => "10.1.0.1" }
        end

        expect(response).to redirect_to join_request_path

        post join_request_path, params: { join_request: details.merge(email: "walker-last@example.com") }, headers: { "REMOTE_ADDR" => "10.1.0.1" }

        expect(response).to redirect_to new_join_request_path(token:)
        expect(flash[:alert]).to eq("Try again later.")
      end

      it "buckets an address-less submission by IP rather than into one shared counter" do
        get new_join_request_path(token: JoinLink.mint(create(:group)))
        post join_request_path, params: { first_name: "Ana" }, headers: { "REMOTE_ADDR" => "10.2.0.1" }
        post join_request_path, params: { first_name: "Ana" }, headers: { "REMOTE_ADDR" => "10.2.0.2" }
        post join_request_path, params: { first_name: "Ana" }, headers: { "REMOTE_ADDR" => "10.2.0.3" }
        post join_request_path, params: { first_name: "Ana" }, headers: { "REMOTE_ADDR" => "10.2.0.4" }

        expect(response).to have_http_status :bad_request
      end
    end

    context "when signed in" do
      it "enqueues the confirmation link and lands on the check-your-email page" do
        sign_in_as create(:user)
        get new_join_request_path(token: JoinLink.mint(create(:group)))

        expect { post join_request_path, params: { join_request: details } }.to have_enqueued_mail(JoinRequestMailer, :link)

        expect(response).to redirect_to join_request_path
      end

      it "answers 404 for a link turned off after the form opened" do
        sign_in_as create(:user)
        group = create(:group)
        get new_join_request_path(token: JoinLink.mint(group))
        group.join_link.destroy!

        post join_request_path, params: { join_request: details }

        expect(response).to have_http_status :not_found
      end
    end
  end

  describe "GET /join" do
    context "when not signed in" do
      it "names the group and the address the link is on its way to" do
        get new_join_request_path(token: JoinLink.mint(create(:group, name: "Riverside Choir")))
        post join_request_path, params: { join_request: details }

        follow_redirect!

        expect(headings(response.body)).to eq([ "Check your email" ])
        expect(page_text(response.body)).to include("Riverside Choir", "ana@example.com")
      end

      it "answers 404 when no join link was opened in this browser" do
        JoinLink.mint(create(:group))

        get join_request_path

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in" do
      it "names the group and the address the link is on its way to" do
        sign_in_as create(:user)
        get new_join_request_path(token: JoinLink.mint(create(:group, name: "Riverside Choir")))
        post join_request_path, params: { join_request: details }

        follow_redirect!

        expect(page_text(response.body)).to include("Riverside Choir", "ana@example.com")
      end

      it "answers 404 when no join link was opened in this browser" do
        sign_in_as create(:user)

        get join_request_path

        expect(response).to have_http_status :not_found
      end
    end
  end

  private
    def details
      { email: "ana@example.com", first_name: "Ana", last_name: "Kovač", mobile_phone: "+385 91 123 4567" }
    end

    # WHY: keyed by the id of the control each error describes, so an assertion proves the message sits under its own field rather than only somewhere on the page.
    def field_errors(body)
      html = Nokogiri::HTML(body)
      html.css("[aria-invalid='true']").to_h { [ it["id"], html.at_css("##{it['aria-describedby']}")&.text&.squish ] }
    end
end
