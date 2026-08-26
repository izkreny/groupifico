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

  # There is no GET /addresses/new and no POST /addresses. An address exists as a detail of the
  # group or event that points at it, both of which build one through nested attributes, so an
  # address created standalone appears in no picker and is reachable by nobody - its own author
  # included. Settled on #172; whether a reusable venue catalogue should exist is #187.
  #
  # Asked of the router itself rather than of a response. Asserting a 404 proves nothing here: the
  # actions and their views are gone too, so the request fails whether the route exists or not, and
  # the example passes with `resources :addresses` fully restored - watched doing exactly that.
  # `recognize_path` fails the moment `only:` is widened, which is the thing worth catching.
  describe "the routes that no longer exist" do
    # Not a RoutingError: with `new` gone from the resource, the `:id` segment of `GET
    # /addresses/:id` swallows the word, so the path resolves to `show` with `id: "new"` and
    # `Address.find("new")` answers 404. What matters is that it no longer reaches a `new` action.
    it "does not route GET /addresses/new to a new action" do
      expect(Rails.application.routes.recognize_path("/addresses/new", method: :get))
        .to include(controller: "addresses", action: "show")
    end

    it "does not route POST /addresses" do
      expect { Rails.application.routes.recognize_path("/addresses", method: :post) }
        .to raise_error(ActionController::RoutingError)
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
  describe "DELETE /addresses/:id" do
    it "is not routable" do
      expect { Rails.application.routes.recognize_path("/addresses/1", method: :delete) }
        .to raise_error(ActionController::RoutingError)
    end
  end
end
