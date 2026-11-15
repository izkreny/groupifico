require 'rails_helper'

RSpec.describe "JoinRequestConfirmations", type: :request do
  describe "GET /join_request_confirmation" do
    context "when not signed in" do
      it "names the group and the address a live request would join" do
        join_link = create(:join_link, group: create(:group, name: "Riverside Choir"))
        token = JoinRequest.mint(join_link:, email: "ana@example.com", first_name: "Ana", last_name: "Kovač", mobile_phone: "+385 91 123 4567")

        get join_request_confirmation_path(token:)

        expect(page_text(response.body)).to include("Riverside Choir", "ana@example.com")
      end

      it "leaves the request unspent" do
        token = JoinRequest.mint(join_link: create(:join_link), email: "ana@example.com", first_name: "Ana", last_name: "Kovač", mobile_phone: "+385 91 123 4567")

        get join_request_confirmation_path(token:)

        expect(JoinRequest.pending(token)).to be_present
      end

      it "answers 404 for a request already spent" do
        token = JoinRequest.mint(join_link: create(:join_link), email: "ana@example.com", first_name: "Ana", last_name: "Kovač", mobile_phone: "+385 91 123 4567")
        JoinRequest.spend!(token)

        get join_request_confirmation_path(token:)

        expect(response).to have_http_status :not_found
      end

      it "answers 404 for a request past its window" do
        token = JoinRequest.mint(join_link: create(:join_link), email: "ana@example.com", first_name: "Ana", last_name: "Kovač", mobile_phone: "+385 91 123 4567")

        travel_to JoinRequest::EXPIRES_IN.from_now + 1.second do
          get join_request_confirmation_path(token:)
        end

        expect(response).to have_http_status :not_found
      end

      it "answers 404 for a token never minted" do
        get join_request_confirmation_path(token: "never-minted")

        expect(response).to have_http_status :not_found
      end

      it "answers 404 for a request carrying no token at all" do
        get join_request_confirmation_path

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in" do
      it "names the group and the address a live request would join" do
        sign_in_as create(:user)
        join_link = create(:join_link, group: create(:group, name: "Riverside Choir"))
        token = JoinRequest.mint(join_link:, email: "ana@example.com", first_name: "Ana", last_name: "Kovač", mobile_phone: "+385 91 123 4567")

        get join_request_confirmation_path(token:)

        expect(page_text(response.body)).to include("Riverside Choir", "ana@example.com")
      end

      it "answers 404 for a token never minted" do
        sign_in_as create(:user)

        get join_request_confirmation_path(token: "never-minted")

        expect(response).to have_http_status :not_found
      end
    end
  end
end
