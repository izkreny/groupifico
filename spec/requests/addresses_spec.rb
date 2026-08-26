require 'rails_helper'

RSpec.describe "Addresses", type: :request do
  describe "GET /addresses" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get addresses_path

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows the addresses page" do
        sign_in_as(create(:user))

        get addresses_path

        expect(response).to have_http_status :ok
      end

      it "lists only addresses reachable through the acting user's groups and events" do
        reachable = create(:address)
        group     = create(:group, address: reachable)
        member    = create(:member, group: group)
        unreachable = create(:address)
        sign_in_as(member.user)

        get addresses_path

        expect(response.body).to include(ActionView::RecordIdentifier.dom_id(reachable))
        expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(unreachable))
      end
    end
  end

  describe "GET /addresses/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get address_path(create(:address))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in and the address is reachable" do
      it "shows the address page" do
        address = create(:address)
        group   = create(:group, address: address)
        member  = create(:member, group: group)

        sign_in_as(member.user)

        get address_path(address)

        expect(response).to have_http_status :ok
      end

      # Destroying is denied for everyone until #172, so the button must not be offered. Asserting
      # the edit button too keeps this honest: without it a page that failed to render its action
      # bar at all would pass.
      it "does not offer the destroy button" do
        address = create(:address)
        group   = create(:group, address: address)
        member  = create(:member, group: group)

        sign_in_as(member.user)

        get address_path(address)

        expect(response.body).to include "Edit this address"
        expect(response.body).not_to include "Destroy this address"
      end

      it "shows an address reached through one of the group's own events" do
        event   = create(:event)
        address = create(:address)
        event.update!(address: address)
        member  = create(:member, group: event.group)

        sign_in_as(member.user)

        get address_path(address)

        expect(response).to have_http_status :ok
      end
    end

    context "when the address belongs to another group's event" do
      it "refuses the request with a redirect carrying an alert" do
        other_event = create(:event)
        address = create(:address)
        other_event.update!(address: address)
        sign_in_as(create(:member).user)

        get address_path(address)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end

    context "when signed in and the address is unreachable" do
      it "refuses the request with a redirect carrying an alert" do
        sign_in_as(create(:user))

        get address_path(create(:address))

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "GET /addresses/new" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get new_address_path

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows the new address page" do
        sign_in_as(create(:user))

        get new_address_path

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "GET /addresses/:id/edit" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get edit_address_path(create(:address))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in and the address is reachable" do
      it "shows the edit address page" do
        address = create(:address)
        group   = create(:group, address: address)
        member  = create(:member, group: group)

        sign_in_as(member.user)

        get edit_address_path(address)

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "POST /addresses" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        post addresses_path, params: { address: { name: "HQ" } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "creates the address" do
        sign_in_as(create(:user))

        expect { post addresses_path, params: { address: { name: "HQ" } } }
          .to change(Address, :count).by(1)

        expect(response).to redirect_to address_path(Address.sole)
      end

      it "re-renders the new page when the address is invalid" do
        sign_in_as(create(:user))

        expect { post addresses_path, params: { address: { name: "" } } }
          .not_to change(Address, :count)

        expect(response).to have_http_status :unprocessable_entity
      end
    end
  end

  describe "PATCH /addresses/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        patch address_path(create(:address)), params: { address: { name: "Renamed" } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "updates the address" do
        address = create(:address)
        group   = create(:group, address: address)
        member  = create(:member, group: group)

        sign_in_as(member.user)

        patch address_path(address), params: { address: { name: "Renamed" } }

        expect(response).to redirect_to address_path(address)
        expect(address.reload.name).to eq "Renamed"
      end

      it "re-renders the edit page when the address is invalid" do
        address = create(:address)
        group   = create(:group, address: address)
        member  = create(:member, group: group)

        sign_in_as(member.user)

        patch address_path(address), params: { address: { name: "" } }

        expect(response).to have_http_status :unprocessable_entity
      end
    end
  end

  # There is no DELETE /addresses/:id. Every address a member can reach is held by an
  # ON DELETE RESTRICT reference from the group or event that makes it reachable, so the action
  # could never succeed for anybody; correcting an address is what `edit` is for. Settled on #172.
  #
  # Asserted through the router rather than the controller, because the route itself is the
  # decision: a controller action added back later would still be unroutable, and this fails the
  # moment `except: :destroy` is dropped from `config/routes.rb`. An unrouted path answers 404
  # here rather than raising, since the test environment rescues routing errors into a response.
  describe "DELETE /addresses/:id" do
    it "is not routable" do
      address = create(:address)

      expect { delete "/addresses/#{address.id}" }
        .not_to change(Address, :count)

      expect(response).to have_http_status :not_found
    end
  end
end
