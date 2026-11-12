require 'rails_helper'

RSpec.describe "JoinRequests", type: :request do
  describe "GET /join/new" do
    context "when not signed in" do
      it "names the group a live link belongs to" do
        token = JoinLink.mint(create(:group, name: "Riverside Choir"))

        get new_join_request_path(token:)

        expect(page_text(response.body)).to include("Riverside Choir")
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
end
