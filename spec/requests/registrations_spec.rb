require 'rails_helper'

RSpec.describe "Registrations", type: :request do
  describe "GET /groups/:group_id/events/:event_id/registrations" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        get group_event_registrations_path(event.group, event)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        event = create(:event)
        sign_in_as(create(:user))

        get group_event_registrations_path(event.group, event)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the registrations page" do
        event = create(:event)
        member = create(:member, :active, group: event.group)
        sign_in_as(member.user)

        get group_event_registrations_path(event.group, event)

        expect(response).to have_http_status :ok
      end

      it "lists only registrations from groups the acting user belongs to" do
        event = create(:event)
        member = create(:member, :active, group: event.group)
        own_registration = create(:registration, event:, member:)
        other_registration = create(:registration)
        sign_in_as(member.user)

        get group_event_registrations_path(event.group, event)

        expect(response.body).to include(ActionView::RecordIdentifier.dom_id(own_registration))
        expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(other_registration))
      end
    end
  end

  describe "GET /groups/:group_id/events/:event_id/registrations/new" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        get new_group_event_registration_path(event.group, event)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        event = create(:event)
        sign_in_as(create(:user))

        get new_group_event_registration_path(event.group, event)

        expect(response).to have_http_status :not_found
      end
    end

    # The invitation row of the events table, which the screen asks as `manage_answers?`: a member
    # holding no role answers for themselves on the event's roster and never opens this screen.
    context "when signed in as a member holding no role" do
      it "refuses with a redirect carrying an alert" do
        event = create(:event)
        member = create(:member, :active, group: event.group)
        sign_in_as(member.user)

        get new_group_event_registration_path(event.group, event)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end

    context "when signed in as the event's manager" do
      it "shows the screen, which is the invitation row" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)

        get new_group_event_registration_path(event.group, event)

        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as an events administrator" do
      it "offers a member with no registration, and lists nobody who already has one" do
        event = create(:event)
        listed = create(:member, :active, group: event.group)
        registered = create(:member, :active, group: event.group)
        create(:registration, event:, member: registered)
        actor = create(:member, :active, :events_administrator, group: event.group)
        sign_in_as(actor.user)

        get new_group_event_registration_path(event.group, event)

        expect(response.body).to include %(id="#{ActionView::RecordIdentifier.dom_id(listed, :invite)}")
        expect(response.body).not_to include %(id="#{ActionView::RecordIdentifier.dom_id(registered)}")
      end

      it "lists a paused member with no checkbox, and omits an inactive one" do
        event = create(:event)
        paused = create(:member, :paused, group: event.group)
        gone = create(:member, :inactive, group: event.group)
        actor = create(:member, :active, :events_administrator, group: event.group)
        sign_in_as(actor.user)

        get new_group_event_registration_path(event.group, event)

        expect(response.body).to include %(id="#{ActionView::RecordIdentifier.dom_id(paused)}")
        expect(response.body).not_to include %(id="#{ActionView::RecordIdentifier.dom_id(paused, :invite)}")
        expect(response.body).not_to include %(id="#{ActionView::RecordIdentifier.dom_id(gone)}")
      end
    end
  end

  describe "POST /groups/:group_id/events/:event_id/registrations" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)
        member = create(:member, group: event.group)

        post group_event_registrations_path(event.group, event), params: { member_ids: [ member.id ] }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and invites nobody" do
        event = create(:event)
        member = create(:member, group: event.group)
        sign_in_as(create(:user))

        expect { post group_event_registrations_path(event.group, event), params: { member_ids: [ member.id ] } }
          .not_to change(Registration, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as a member holding no role" do
      it "refuses with a redirect carrying an alert, and invites nobody" do
        event = create(:event)
        member = create(:member, :active, group: event.group)
        sign_in_as(member.user)

        expect { post group_event_registrations_path(event.group, event), params: { member_ids: [ member.id ] } }
          .not_to change(Registration, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and invites nobody" do
        event = create(:event)
        member = create(:member, :paused, group: event.group)
        sign_in_as(member.user)

        expect { post group_event_registrations_path(event.group, event), params: { member_ids: [ member.id ] } }
          .not_to change(Registration, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end

    # Filling the event is the manager's job and the three roles', and saying `invited` is part of
    # it. A member speaking for themselves says `yes`, `maybe` or `no` on the event's own roster.
    context "when signed in as the event's manager" do
      it "invites every ticked member at once, as invited" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        first = create(:member, :active, group: actor.group)
        second = create(:member, :active, group: actor.group)
        sign_in_as(actor.user)

        expect { post group_event_registrations_path(event.group, event), params: { member_ids: [ "", first.id, second.id ] } }
          .to change(Registration, :count).by(2)

        expect(event.registrations.pluck(:status)).to all eq "invited"
        expect(response).to redirect_to group_event_path(event.group, event)
      end
    end

    context "when signed in as an events administrator" do
      it "re-renders the screen when nothing was ticked" do
        event = create(:event)
        actor = create(:member, :active, :events_administrator, group: event.group)
        sign_in_as(actor.user)

        expect { post group_event_registrations_path(event.group, event), params: { member_ids: [ "" ] } }
          .not_to change(Registration, :count)

        expect(response).to have_http_status :unprocessable_content
      end

      it "ignores a ticked member who is paused, inactive or already registered" do
        event = create(:event)
        paused = create(:member, :paused, group: event.group)
        gone = create(:member, :inactive, group: event.group)
        registered = create(:member, :active, group: event.group)
        create(:registration, event:, member: registered)
        actor = create(:member, :active, :events_administrator, group: event.group)
        sign_in_as(actor.user)

        expect { post group_event_registrations_path(event.group, event), params: { member_ids: [ paused.id, gone.id, registered.id ] } }
          .not_to change(Registration, :count)
      end

      it "ignores a ticked member from another group, whose name is nobody here's to publish" do
        event = create(:event)
        outsider = create(:member, :active)
        actor = create(:member, :active, :events_administrator, group: event.group)
        sign_in_as(actor.user)

        expect { post group_event_registrations_path(event.group, event), params: { member_ids: [ outsider.id ] } }
          .not_to change(Registration, :count)

        expect(event.reload.attendees).not_to include outsider
      end
    end
  end

  describe "PATCH /groups/:group_id/events/:event_id/registrations/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        registration = create(:registration)

        patch group_event_registration_path(registration.event.group, registration.event, registration), params: { registration: { status: "yes" } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and leaves the registration unchanged" do
        registration = create(:registration, status: "reserved")
        sign_in_as(create(:user))

        patch group_event_registration_path(registration.event.group, registration.event, registration), params: { registration: { status: "yes" } }

        expect(response).to have_http_status :not_found
        expect(registration.reload.status).to eq "reserved"
      end
    end

    context "when signed in as an events administrator" do
      it "updates the registration" do
        event = create(:event)
        registration = create(:registration, event:, member: create(:member, group: event.group))
        actor = create(:member, :active, :events_administrator, group: event.group)
        sign_in_as(actor.user)

        patch group_event_registration_path(event.group, event, registration), params: { registration: { status: "yes" } }

        expect(response).to redirect_to group_event_path(event.group, event)
        expect(registration.reload.status).to eq "yes"
      end

      # An answer is a button rather than a field, so a refused write has no form to return to:
      # the message lands on the screen the buttons live on.
      it "returns to the event with the message when the status is invalid" do
        event = create(:event)
        registration = create(:registration, event:, member: create(:member, group: event.group))
        actor = create(:member, :active, :events_administrator, group: event.group)
        sign_in_as(actor.user)

        patch group_event_registration_path(event.group, event, registration), params: { registration: { status: "bogus" } }

        expect(response).to redirect_to group_event_path(event.group, event)
        expect(flash[:alert]).to be_present
      end

      # member_id is not permitted on update at all, so an events administrator cannot hand a
      # registration on either. Correcting who a registration is for is deleting it and making
      # another, which the events table already decides.
      it "cannot move a registration onto another member" do
        event = create(:event)
        holder = create(:member, group: event.group)
        registration = create(:registration, event:, member: holder)
        other = create(:member, group: event.group)
        actor = create(:member, :active, :events_administrator, group: event.group)
        sign_in_as(actor.user)

        patch group_event_registration_path(event.group, event, registration), params: { registration: { member_id: other.id, status: "yes" } }

        expect(registration.reload.member).to eq holder
      end

      it "changes another member's answer, which the manager may not" do
        event = create(:event)
        registration = create(:registration, status: "yes", event:, member: create(:member, group: event.group))
        manager = create(:member, :active, group: event.group)
        event.update!(manager: manager)
        sign_in_as(manager.user)

        patch group_event_registration_path(event.group, event, registration), params: { registration: { status: "no" } }

        expect(response).to redirect_to root_path
        expect(registration.reload.status).to eq "yes"
      end

      it "lets a member change their own answer while holding no role" do
        event = create(:event)
        actor = create(:member, :active, group: event.group)
        registration = create(:registration, status: "reserved", event:, member: actor)
        sign_in_as(actor.user)

        patch group_event_registration_path(event.group, event, registration), params: { registration: { status: "yes" } }

        expect(registration.reload.status).to eq "yes"
      end

      it "refuses a member writing invited onto their own registration" do
        event = create(:event)
        actor = create(:member, :active, group: event.group)
        registration = create(:registration, status: "yes", event:, member: actor)
        sign_in_as(actor.user)

        patch group_event_registration_path(event.group, event, registration), params: { registration: { status: "invited" } }

        expect(response).to redirect_to root_path
        expect(registration.reload.status).to eq "yes"
      end

      it "ignores a posted event_id, leaving the registration on its own event" do
        event = create(:event)
        registration = create(:registration, event:, member: create(:member, group: event.group))
        original_event = registration.event
        other_event = create(:event)
        actor = create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        patch group_event_registration_path(event.group, event, registration), params: { registration: { event_id: other_event.id } }

        expect(registration.reload.event).to eq original_event
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and leaves the registration unchanged" do
        event = create(:event)
        registration = create(:registration, event:, member: create(:member, group: event.group), status: "reserved")
        actor = create(:member, :paused, group: event.group)
        sign_in_as(actor.user)

        patch group_event_registration_path(event.group, event, registration), params: { registration: { status: "yes" } }

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
        expect(registration.reload.status).to eq "reserved"
      end
    end
  end

  describe "DELETE /groups/:group_id/events/:event_id/registrations/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        registration = create(:registration)

        expect { delete group_event_registration_path(registration.event.group, registration.event, registration) }
          .not_to change(Registration, :count)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and does not destroy the registration" do
        registration = create(:registration)
        sign_in_as(create(:user))

        expect { delete group_event_registration_path(registration.event.group, registration.event, registration) }
          .not_to change(Registration, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an events administrator" do
      it "destroys the registration" do
        event = create(:event)
        registration = create(:registration, event:, member: create(:member, group: event.group))
        actor = create(:member, :active, :events_administrator, group: event.group)
        sign_in_as(actor.user)

        expect { delete group_event_registration_path(event.group, event, registration) }
          .to change(Registration, :count).by(-1)

        expect(response).to redirect_to group_event_path(event.group, event)
      end
    end

    # A registration is answered, never withdrawn: declining is the `no` answer, so nobody removes
    # their own and the manager does not remove anybody's.
    # update? is decided against the record as loaded, so a member passes it on their own
    # registration before any posted member_id is applied. Permitting member_id there let them
    # answer for somebody else and lose their own registration in the same request - two capabilities
    # the events table gives the three roles, and one it gives nobody.
    context "when a member posts another member's id onto their own registration" do
      it "leaves the registration where it was, and answers for nobody else" do
        event = create(:event)
        actor = create(:member, :active, group: event.group)
        other = create(:member, group: event.group)
        registration = create(:registration, status: "reserved", event:, member: actor)
        sign_in_as(actor.user)

        patch group_event_registration_path(event.group, event, registration),
          params: { registration: { member_id: other.id, status: "yes" } }

        expect(registration.reload.member).to eq actor
        expect(other.registrations).to be_empty
      end
    end

    context "when signed in as the member the registration is for" do
      it "refuses, leaving them to answer no instead" do
        event = create(:event)
        actor = create(:member, :active, group: event.group)
        registration = create(:registration, event:, member: actor)
        sign_in_as(actor.user)

        expect { delete group_event_registration_path(event.group, event, registration) }
          .not_to change(Registration, :count)

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as the event's manager" do
      it "refuses, because taking a registration away is not theirs" do
        event = create(:event)
        manager = create(:member, :active, group: event.group)
        event.update!(manager: manager)
        registration = create(:registration, event:, member: create(:member, group: event.group))
        sign_in_as(manager.user)

        expect { delete group_event_registration_path(event.group, event, registration) }
          .not_to change(Registration, :count)

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and does not destroy the registration" do
        event = create(:event)
        registration = create(:registration, event:, member: create(:member, group: event.group))
        actor = create(:member, :paused, group: event.group)
        sign_in_as(actor.user)

        expect { delete group_event_registration_path(event.group, event, registration) }
          .not_to change(Registration, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end
  end
end
