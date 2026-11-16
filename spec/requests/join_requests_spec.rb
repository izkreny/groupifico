require 'rails_helper'

RSpec.describe "JoinRequests", type: :request do
  describe "GET /join/new" do
    context "when not signed in" do
      it "names the group a live link belongs to" do
        token = JoinLink.mint(create(:group, name: "Riverside Choir"))

        get new_join_request_path(token:)

        expect(page_text(response.body)).to include("Riverside Choir")
      end

      # WHY: #446 AC1, the form asking for an email alone and carrying the link's token to the submission.
      it "offers a form asking only for an email, posting the link's token to the sign-in link" do
        token = JoinLink.mint(create(:group))

        get new_join_request_path(token:)

        expect(response.body).to include(%(action="#{join_request_sign_in_link_path}"), 'name="user[email]"')
        expect(response.body).to match(/<input type="hidden" name="token" [^>]*value="#{token}"/)
        expect(response.body.scan(/<input(?![^>]*type="hidden")[^>]*>/).size).to eq 1
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

      # WHY: a signed-in visitor has nothing to ask a sign-in link for; what they see instead is #447's.
      it "offers no email form" do
        sign_in_as create(:user)
        token = JoinLink.mint(create(:group))

        get new_join_request_path(token:)

        expect(response.body).not_to include(join_request_sign_in_link_path)
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
end
