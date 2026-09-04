require 'rails_helper'

RSpec.describe "Events", type: :request do
  describe "GET /groups/:group_id/events" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get group_events_path(create(:group))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        sign_in_as(create(:user))

        get group_events_path(create(:group))

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the events page" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response).to have_http_status :ok
      end

      it "lists only events from groups the acting user belongs to" do
        member = create(:member, :active)
        own_event = create(:event, group: member.group, creator: member)
        other_event = create(:event)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response.body).to include(ActionView::RecordIdentifier.dom_id(own_event))
        expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(other_event))
      end
    end
  end

  describe "GET /groups/:group_id/events/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        get group_event_path(event.group, event)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        event = create(:event)
        sign_in_as(create(:user))

        get group_event_path(event.group, event)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the event page" do
        event = create(:event)
        sign_in_as(event.creator.user)

        get group_event_path(event.group, event)

        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as a paused member" do
      it "shows the event page" do
        event = create(:event)
        member = create(:member, :paused, group: event.group)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as an inactive member" do
      it "returns 404, exactly like a non-member" do
        event = create(:event)
        member = create(:member, :inactive, group: event.group)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(response).to have_http_status :not_found
      end
    end
  end

  describe "GET /groups/:group_id/events/new" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get new_group_event_path(create(:group))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        sign_in_as(create(:user))

        get new_group_event_path(create(:group))

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an events administrator" do
      it "shows the new event page" do
        member = create(:member, :active, :events_administrator)
        sign_in_as(member.user)

        get new_group_event_path(member.group)

        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as a member who cannot create events" do
      it "refuses the form rather than offering one the submission would reject" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get new_group_event_path(member.group)

        expect(response).to redirect_to root_path
      end
    end
  end

  describe "GET /groups/:group_id/events/:id/duplicate" do
    # `duplicate` renders the `new` form, and `new` resolves new? through create?, so a rule that
    # let a paused member through here contradicted the one guarding the other door onto it.
    context "when signed in as a paused member" do
      it "refuses, exactly as new does" do
        event = create(:event)
        actor = create(:member, :paused, group: event.group)
        sign_in_as(actor.user)

        get duplicate_group_event_path(event.group, event)

        expect(response).to redirect_to root_path
      end
    end

    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        get duplicate_group_event_path(event.group, event)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        event = create(:event)
        sign_in_as(create(:user))

        get duplicate_group_event_path(event.group, event)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as the event's manager" do
      it "cannot duplicate the event, which is creating one" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)

        get duplicate_group_event_path(event.group, event)

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as an events administrator" do
      it "renders the new event page" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        get duplicate_group_event_path(event.group, event)

        expect(response).to have_http_status :ok
      end

      # `Event#duplicate` is `dup`, so the copy carries the original's `creator_id`. Nothing submits
      # it, which is what makes the duplicate belong to whoever saves it rather than to whoever made
      # the original.
      it "carries no creator into the form" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        get duplicate_group_event_path(event.group, event)

        expect(response.body).not_to include "event[creator_id]"
      end
    end
  end

  describe "GET /groups/:group_id/events/:id/edit" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        get edit_group_event_path(event.group, event)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        event = create(:event)
        sign_in_as(create(:user))

        get edit_group_event_path(event.group, event)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an events administrator" do
      it "shows the edit event page" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as the event's manager" do
      it "shows the edit event page, holding no role at all" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(response).to have_http_status :ok
      end
    end

    # Creating an event is a record of who made it and confers nothing afterwards: the role that
    # allowed it may be gone tomorrow while the column stays.
    context "when signed in as the event's creator, holding no role" do
      it "refuses the form" do
        event = create(:event)
        sign_in_as(event.creator.user)

        get edit_group_event_path(event.group, event)

        expect(response).to redirect_to root_path
      end
    end
  end

  describe "POST /groups/:group_id/events" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        group = create(:group)

        post group_events_path(group), params: { event: { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and does not create the event" do
        group  = create(:group)
        params = { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour }
        sign_in_as(create(:user))

        expect { post group_events_path(group), params: { event: params } }
          .not_to change(Event, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an events administrator" do
      # The creator assertion belongs here rather than only in the model spec: the default reads
      # `Current.user`, and only a real request proves the session is resumed before the create
      # runs. A reordering that left it unset would pass every model spec.
      it "creates the event with the signed-in member as its creator" do
        creator = create(:member, :active, :events_administrator)
        sign_in_as(creator.user)
        params  = { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour }

        expect { post group_events_path(creator.group), params: { event: params } }.to change(Event, :count).by(1)
        expect(response).to redirect_to group_event_path(creator.group, Event.sole)
        expect(Event.sole.creator).to eq creator
      end

      it "re-renders the new page when the event is invalid" do
        member = create(:member, :active, :events_administrator)
        sign_in_as(member.user)

        expect { post group_events_path(member.group), params: { event: { name: "" } } }
          .not_to change(Event, :count)

        expect(response).to have_http_status :unprocessable_content
      end

      it "creates no event for a member who manages one but holds no role" do
        actor = create(:member, :active)
        create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)
        params = { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour }

        expect { post group_events_path(actor.group), params: { event: params } }
          .not_to change(Event, :count)

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and does not create the event" do
        member = create(:member, :paused)
        params = { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour }
        sign_in_as(member.user)

        expect { post group_events_path(member.group), params: { event: params } }
          .not_to change(Event, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /groups/:group_id/events/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        patch group_event_path(event.group, event), params: { event: { name: "Renamed" } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and leaves the event unchanged" do
        event = create(:event, name: "Original")
        sign_in_as(create(:user))

        patch group_event_path(event.group, event), params: { event: { name: "Renamed" } }

        expect(response).to have_http_status :not_found
        expect(event.reload.name).to eq "Original"
      end
    end

    context "when signed in as an events administrator" do
      it "updates the event" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { name: "Renamed" } }

        expect(response).to redirect_to group_event_path(event.group, event)
        expect(event.reload.name).to eq "Renamed"
      end

      it "re-renders the edit page when the event is invalid" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { name: "" } }

        expect(response).to have_http_status :unprocessable_content
      end

      it "ignores a posted group_id, leaving the event in its own group" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        other_group = create(:group)
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { group_id: other_group.id } }

        expect(event.reload.group).to eq actor.group
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and leaves the event unchanged" do
        event = create(:event, name: "Original")
        member = create(:member, :paused, group: event.group)
        sign_in_as(member.user)

        patch group_event_path(event.group, event), params: { event: { name: "Renamed" } }

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
        expect(event.reload.name).to eq "Original"
      end
    end
  end

  describe "DELETE /groups/:group_id/events/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        expect { delete group_event_path(event.group, event) }
          .not_to change(Event, :count)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and does not destroy the event" do
        event = create(:event)
        sign_in_as(create(:user))

        expect { delete group_event_path(event.group, event) }
          .not_to change(Event, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an events administrator" do
      it "destroys the event" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        expect { delete group_event_path(event.group, event) }
          .to change(Event, :count).by(-1)

        expect(response).to redirect_to group_events_path(event.group)
      end
    end

    context "when signed in as the event's manager" do
      it "refuses, because filling an event is the manager's job and deleting one is not" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)

        expect { delete group_event_path(event.group, event) }
          .not_to change(Event, :count)

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and does not destroy the event" do
        event = create(:event)
        member = create(:member, :paused, group: event.group)
        sign_in_as(member.user)

        expect { delete group_event_path(event.group, event) }
          .not_to change(Event, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "foreign keys posted in the body" do
    # Pointing an event at another group's address is what makes it an owner of that address - and
    # so lets it be edited - by somebody with no claim on it. The picker is scoped; the parameter
    # was not.
    it "ignores an address_id belonging to another group" do
      event = create(:event, address: create(:address))
      actor = create(:member, :active, group: event.group)
      elsewhere = create(:address, name: "Someone Else's Venue")
      create(:group, address: elsewhere)
      sign_in_as(actor.user)

      patch group_event_path(event.group, event), params: { event: { address_id: elsewhere.id } }

      expect(event.reload.address).not_to eq elsewhere
    end

    # A member of the event's own group, holding the role that carries the update through, and a
    # name posted alongside so the update is one that lands: the new name proves the request was
    # processed and the unchanged creator proves the parameter is gone rather than guarded. An
    # outsider's id would prove neither, since the guard that used to drop it and the parameter's
    # absence are indistinguishable from out there.
    it "ignores a creator_id, even one from the event's own group" do
      actor = create(:member, :active, :events_administrator)
      event = create(:event, group: actor.group)
      sign_in_as(actor.user)

      patch group_event_path(event.group, event), params: { event: { name: "Renamed", creator_id: actor.id } }

      expect(event.reload.name).to eq "Renamed"
      expect(event.creator).not_to eq actor
    end

    # The second door onto an address, and the one the policy cannot see. `address_attributes` with
    # an `:id` would have `accepts_nested_attributes_for` update that address in place with only
    # `EventPolicy#update?` asked, so an events_administrator edited the group's home address that
    # `AddressPolicy` reserves to the `owner`. The name posted alongside proves the request landed,
    # so an unchanged address is the parameter being dropped rather than the whole update failing.
    it "ignores address_attributes naming an existing address" do
      home  = create(:address, name: "Rehearsal Hall")
      group = create(:group, address: home)
      event = create(:event, group:, address: home)
      actor = create(:member, :active, :events_administrator, group:)
      sign_in_as(actor.user)

      patch group_event_path(group, event),
        params: { event: { name: "Renamed", address_attributes: { id: home.id, name: "Hijacked" } } }

      expect(event.reload.name).to eq "Renamed"
      expect(home.reload.name).to eq "Rehearsal Hall"
    end
  end

  describe "an inactive member's event list" do
    it "does not include the former group's events" do
      event = create(:event, name: "Rehearsal")
      actor = create(:member, :inactive, group: event.group)
      sign_in_as(actor.user)

      get group_events_path(event.group)

      expect(response).to have_http_status :not_found
    end
  end
end
