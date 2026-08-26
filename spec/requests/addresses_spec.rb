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
    end

    context "when signed in and the address is unreachable" do
      it "refuses the request" do
        sign_in_as(create(:user))

        get address_path(create(:address))

        expect(response).to have_http_status :forbidden
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

  describe "DELETE /addresses/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        create(:address)

        expect { delete address_path(Address.sole) }
          .not_to change(Address, :count)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in" do
      # Destroying is denied for everyone until #172, reachable addresses included: the group or
      # event that makes an address reachable also holds an ON DELETE RESTRICT reference to it,
      # so permitting this would trade a 403 for a foreign key violation. Reaching the address is
      # the point of the setup below - it is the case that breaks if destroy? goes back to
      # aliasing show?.
      it "refuses to destroy an address the user can otherwise reach" do
        address = create(:address)
        group   = create(:group, address: address)
        member  = create(:member, group: group)

        sign_in_as(member.user)

        expect { delete address_path(address) }
          .not_to change(Address, :count)

        expect(response).to have_http_status :forbidden
      end
    end
  end
end
