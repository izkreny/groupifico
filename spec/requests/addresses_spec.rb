require 'rails_helper'

RSpec.describe "Addresses", type: :request do
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
        member  = create(:member, group:)

        sign_in_as(member.user)

        get address_path(address)

        expect(response).to have_http_status :ok
      end

      # Frame 9k: the pushed title, then the name, the lines of the address and whose home it is.
      it "shows the place under its pushed title" do
        address = create(:address, name: "Community Hall", street_name: "Obala", building_number: "14", postal_code: "10000", city: "Zagreb", country_code: "HR")
        member  = create(:member, group: create(:group, name: "Riverside Choir", address:))
        sign_in_as(member.user)

        get address_path(address)

        expect(page_text(response.body)).to include "Place Community Hall", "Obala 14 10000 Zagreb HR", "Riverside Choir · home address"
      end

      it "links the street to the reader's map application" do
        address = create(:address, street_name: "Obala", building_number: "14")
        member  = create(:member, group: create(:group, address:))
        sign_in_as(member.user)

        get address_path(address)
        street = Nokogiri::HTML(response.body).at_xpath("//a[normalize-space()='Obala 14']")

        expect(street["href"]).to start_with "https://www.google.com/maps/search/"
      end

      it "links the area line instead for a place with no street" do
        address = create(:address, street_name: nil, building_number: nil, postal_code: "10000", city: "Zagreb")
        member  = create(:member, group: create(:group, address:))
        sign_in_as(member.user)

        get address_path(address)
        area = Nokogiri::HTML(response.body).at_xpath("//a[normalize-space()='10000 Zagreb']")

        expect(area["href"]).to start_with "https://www.google.com/maps/search/"
        expect(page_text(response.body).scan("10000 Zagreb").size).to eq 1
      end

      it "links the name instead for a place that is a name and nothing else" do
        address = create(:address, name: "Community Hall", street_name: nil, building_number: nil, postal_code: nil, city: nil)
        member  = create(:member, group: create(:group, address:))
        sign_in_as(member.user)

        get address_path(address)
        name = Nokogiri::HTML(response.body).at_xpath("//h2/a[normalize-space()='Community Hall']")

        expect(name["href"]).to start_with "https://www.google.com/maps/search/"
      end

      it "leaves the name unlinked where an address line carries the map" do
        address = create(:address, name: "Community Hall", street_name: "Obala", building_number: "14")
        member  = create(:member, group: create(:group, address:))
        sign_in_as(member.user)

        get address_path(address)

        expect(page_text(response.body)).to include "Community Hall"
        expect(Nokogiri::HTML(response.body).at_xpath("//h2/a")).to be_nil
      end

      it "lists the events using the place, earliest first, each with its start" do
        address = create(:address)
        group   = create(:group)
        later   = create(:event, group:, address:, name: "Extra gig", starts_at: Time.zone.local(2026, 10, 3, 20, 0))
        create(:event, group:, address:, name: "Tuesday rehearsal", starts_at: Time.zone.local(2026, 9, 1, 19, 0))
        member  = create(:member, group:)
        sign_in_as(member.user)

        get address_path(address)

        expect(page_text(response.body)).to include "Used by Tuesday rehearsal Tue 1 Sep · 19:00 Extra gig Sat 3 Oct · 20:00"
        expect(Nokogiri::HTML(response.body).at_xpath("//a[normalize-space()='Extra gig']")["href"]).to eq group_event_path(group, later)
      end

      it "says nothing about a home for a place only events use" do
        address = create(:address)
        event   = create(:event, address:)
        member  = create(:member, group: event.group)
        sign_in_as(member.user)

        get address_path(address)

        expect(page_text(response.body)).to include "Used by"
        expect(page_text(response.body)).not_to include "home address"
      end

      it "draws no Used by for a place no event uses" do
        address = create(:address, name: "Community Hall")
        member  = create(:member, group: create(:group, address:))
        sign_in_as(member.user)

        get address_path(address)

        expect(page_text(response.body)).to include "Community Hall"
        expect(page_text(response.body)).not_to include "Used by"
      end

      # A delete could never succeed, since every address a member can reach is held by an
      # ON DELETE RESTRICT reference, so no form on the page may post to the address at all. Correct
      # is asserted beside it so a page that drew none of its controls cannot pass.
      it "offers the owner Correct and never a delete" do
        address = create(:address)
        member  = create(:member, :owner, group: create(:group, address:))
        sign_in_as(member.user)

        get address_path(address)
        document = Nokogiri::HTML(response.body)

        expect(document.at_xpath("//a[normalize-space()='Correct']")["href"]).to eq edit_address_path(address)
        expect(document.at_css("form[action='#{address_path(address)}']")).to be_nil
      end

      # `AddressPolicy#update?` reserves a group's home address to the owner, so a member reads it
      # with no control to correct it.
      it "offers Correct to nobody the policy refuses" do
        address = create(:address, name: "Community Hall")
        member  = create(:member, group: create(:group, address:))
        sign_in_as(member.user)

        get address_path(address)

        expect(page_text(response.body)).to include "Community Hall"
        expect(Nokogiri::HTML(response.body).at_xpath("//a[normalize-space()='Correct']")).to be_nil
      end
    end

    context "when the address belongs to another group's event" do
      # 404 rather than the redirect, and that is the inheritance paying off. The rule now asks
      # EventPolicy, whose membership pre-check denies with a `not_found` detail, and the detail
      # travels back through `allowed_to?` into this policy's own result - so a non-member is told the
      # address does not exist rather than that they may not have it, which is the whole reason
      # ADR 0003 chose 404 over 403. The old rule answered plain false and leaked the difference.
      it "answers as if the address did not exist" do
        other_event = create(:event)
        address = create(:address)
        other_event.update!(address: address)
        sign_in_as(create(:member).user)

        get address_path(address)

        expect(response).to have_http_status :not_found
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
  # included. Settled on #172; a venue catalogue crossing groups was declined on #187 - an address
  # belongs to one group, and the event form already reuses the ones that group has.
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

    # No list of addresses either: frames 9k and 9l reach a place only from the group or event that
    # uses it, and nothing linked to the scaffold's list. Removed on #255.
    it "does not route GET /addresses" do
      expect { Rails.application.routes.recognize_path("/addresses", method: :get) }
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
      it "shows the edit address page to a member who may correct it" do
        address = create(:address)
        member  = create(:member, :owner, group: create(:group, address:))
        sign_in_as(member.user)

        get edit_address_path(address)

        expect(response).to have_http_status :ok
      end

      # The form is asked of the rule its Save is, so a member who may only read the address is
      # refused it rather than offered a Save certain to fail.
      it "refuses the form to a member who may not correct the address" do
        address = create(:address)
        member  = create(:member, group: create(:group, address:))
        sign_in_as(member.user)

        get edit_address_path(address)

        expect(response).to redirect_to root_path
      end

      it "refuses the form to a paused owner" do
        address = create(:address)
        member  = create(:member, :paused, :owner, group: create(:group, address:))
        sign_in_as(member.user)

        get edit_address_path(address)

        expect(response).to redirect_to root_path
      end

      # Frame 9l's five, and none of the columns it leaves out: the state and the coordinates keep
      # whatever they hold.
      it "draws the five fields under their frame names, Name with its hint" do
        address = create(:address)
        member  = create(:member, :owner, group: create(:group, address:))
        sign_in_as(member.user)

        get edit_address_path(address)
        document = Nokogiri::HTML(response.body)

        expect(document.css("form label.label").map { it.text.strip }).to eq [ "Name", "Street", "Number", "Postcode", "City", "Country" ]
        expect(document.at_css("#address_name_hint").text).to eq "As it reads on cards"
        expect(document.css("#address_state_code, #address_latitude, #address_longitude")).to be_empty
      end

      it "notes how many events in the group move with a correction" do
        address = create(:address)
        group   = create(:group, name: "Riverside Choir", address:)
        create_list(:event, 2, group:, address:)
        member  = create(:member, :owner, group:)
        sign_in_as(member.user)

        get edit_address_path(address)

        expect(page_text(response.body)).to include "Used by 2 events in Riverside Choir. They all move with it."
      end

      it "says the one event moves with a correction when only one uses the place" do
        address = create(:address)
        group   = create(:group, name: "Riverside Choir", address:)
        create(:event, group:, address:)
        member  = create(:member, :owner, group:)
        sign_in_as(member.user)

        get edit_address_path(address)

        expect(page_text(response.body)).to include "Used by 1 event in Riverside Choir. That event moves with it."
      end

      it "leaves the note out when no event uses the place" do
        address = create(:address)
        member  = create(:member, :owner, group: create(:group, address:))
        sign_in_as(member.user)

        get edit_address_path(address)

        expect(page_text(response.body)).to include "Street and number"
        expect(page_text(response.body)).not_to include "Used by"
      end

      it "cancels back to the place and offers no delete" do
        address = create(:address)
        member  = create(:member, :owner, group: create(:group, address:))
        sign_in_as(member.user)

        get edit_address_path(address)
        document = Nokogiri::HTML(response.body)

        expect(document.at_xpath("//a[normalize-space()='Cancel']")["href"]).to eq address_path(address)
        expect(document.at_css("form[action='#{address_path(address)}'] input[name='_method'][value='delete']")).to be_nil
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

    # An address inherits its owner's answer, so the group's home address is the owner's to correct
    # and nobody else's. Nothing in AddressPolicy says so: GroupPolicy#update? tightened and this
    # followed.
    context "when signed in as the group's owner" do
      it "updates the address" do
        address = create(:address)
        group   = create(:group, address: address)
        member  = create(:member, :owner, group:)

        sign_in_as(member.user)

        patch address_path(address), params: { address: { name: "Renamed" } }

        expect(response).to redirect_to address_path(address)
        expect(address.reload.name).to eq "Renamed"
      end

      it "re-renders the edit page when the address is invalid" do
        address = create(:address)
        group   = create(:group, address: address)
        member  = create(:member, :owner, group:)

        sign_in_as(member.user)

        patch address_path(address), params: { address: { name: "" } }

        expect(response).to have_http_status :unprocessable_content
      end

      # The one layer that ties the aria pair to the control that failed. `spec/system` is excluded
      # from every GitHub Actions job per `.agents/gh-solo.md`, so an edit dropping the pair or
      # renaming the note's id would otherwise reach `main` with four green checks. The ids are the
      # ones #239 promises the request specs keep asserting, #178's among them.
      #
      # The message's own text belongs to `spec/form_builders/app_form_builder_spec.rb`, which
      # asserts it in "replaces the hint with the error"; that layer runs in the `test` job too, so
      # repeating the text here would only make one edit fail in two places.
      it "points the failed control at its own error message" do
        member  = create(:member, :owner, :with_all_attributes)
        sign_in_as(member.user)

        patch address_path(member.group.address), params: { address: { name: "" } }
        control = Nokogiri::HTML(response.body).at_css("input#address_name")

        expect(Nokogiri::HTML(response.body).at_css("p#address_name_error")).to be_present
        expect(control["aria-invalid"]).to eq "true"
        expect(control["aria-describedby"]).to eq "address_name_error"
      end

      it "shows the summary alert above the fields" do
        member = create(:member, :owner, :with_all_attributes)
        sign_in_as(member.user)

        patch address_path(member.group.address), params: { address: { name: "" } }

        expect(page_text(response.body)).to include "Please fix the highlighted fields."
      end
    end

    context "when signed in as a member who does not own the group" do
      it "refuses the correction and leaves the address alone" do
        address = create(:address, name: "Original")
        group   = create(:group, address: address)
        member  = create(:member, group:)

        sign_in_as(member.user)

        patch address_path(address), params: { address: { name: "Renamed" } }

        expect(response).to redirect_to root_path
        expect(address.reload.name).to eq "Original"
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
