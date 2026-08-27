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

    context "when signed in as a stranger" do
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
        member = create(:member, status: :active, group: event.group)
        sign_in_as(member.user)

        get group_event_registrations_path(event.group, event)

        expect(response).to have_http_status :ok
      end

      it "lists only registrations from groups the acting user belongs to" do
        event = create(:event)
        member = create(:member, status: :active, group: event.group)
        own_registration = create(:registration, event:, member:)
        other_registration = create(:registration)
        sign_in_as(member.user)

        get group_event_registrations_path(event.group, event)

        expect(response.body).to include(ActionView::RecordIdentifier.dom_id(own_registration))
        expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(other_registration))
      end
    end
  end

  describe "GET /groups/:group_id/events/:event_id/registrations/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        registration = create(:registration)

        get group_event_registration_path(registration.event.group, registration.event, registration)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a stranger" do
      it "returns 404" do
        registration = create(:registration)
        sign_in_as(create(:user))

        get group_event_registration_path(registration.event.group, registration.event, registration)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the registration page" do
        event = create(:event)
        registration = create(:registration, event:, member: create(:member, group: event.group))
        viewer = create(:member, status: :active, group: event.group)
        sign_in_as(viewer.user)

        get group_event_registration_path(event.group, event, registration)

        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as a paused member" do
      it "shows the registration page" do
        event = create(:event)
        registration = create(:registration, event:, member: create(:member, group: event.group))
        viewer = create(:member, :paused, group: event.group)
        sign_in_as(viewer.user)

        get group_event_registration_path(event.group, event, registration)

        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as an inactive member" do
      it "returns 404, exactly like a stranger" do
        event = create(:event)
        registration = create(:registration, event:, member: create(:member, group: event.group))
        viewer = create(:member, :inactive, group: event.group)
        sign_in_as(viewer.user)

        get group_event_registration_path(event.group, event, registration)

        expect(response).to have_http_status :not_found
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

    context "when signed in as a stranger" do
      it "returns 404" do
        event = create(:event)
        sign_in_as(create(:user))

        get new_group_event_registration_path(event.group, event)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the new registration page" do
        event = create(:event)
        member = create(:member, status: :active, group: event.group)
        sign_in_as(member.user)

        get new_group_event_registration_path(event.group, event)

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "GET /groups/:group_id/events/:event_id/registrations/:id/edit" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        registration = create(:registration)

        get edit_group_event_registration_path(registration.event.group, registration.event, registration)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a stranger" do
      it "returns 404" do
        registration = create(:registration)
        sign_in_as(create(:user))

        get edit_group_event_registration_path(registration.event.group, registration.event, registration)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the edit registration page" do
        event = create(:event)
        registration = create(:registration, event:, member: create(:member, group: event.group))
        viewer = create(:member, status: :active, group: event.group)
        sign_in_as(viewer.user)

        get edit_group_event_registration_path(event.group, event, registration)

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "POST /groups/:group_id/events/:event_id/registrations" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)
        member = create(:member, group: event.group)

        post group_event_registrations_path(event.group, event), params: { registration: { member_id: member.id } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a stranger" do
      it "returns 404 and does not create the registration" do
        event = create(:event)
        member = create(:member, group: event.group)
        sign_in_as(create(:user))

        expect { post group_event_registrations_path(event.group, event), params: { registration: { member_id: member.id } } }
          .not_to change(Registration, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "creates the registration" do
        event = create(:event)
        member = create(:member, status: :active, group: event.group)
        sign_in_as(member.user)

        expect { post group_event_registrations_path(event.group, event), params: { registration: { member_id: member.id } } }.to change(Registration, :count).by(1)
        expect(response).to redirect_to group_event_registration_path(event.group, event, Registration.sole)
      end

      it "re-renders the new page when the registration is invalid" do
        event = create(:event)
        member = create(:member, status: :active, group: event.group)
        sign_in_as(member.user)

        expect { post group_event_registrations_path(event.group, event), params: { registration: { member_id: "" } } }
          .not_to change(Registration, :count)

        expect(response).to have_http_status :unprocessable_entity
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and does not create the registration" do
        event = create(:event)
        member = create(:member, :paused, group: event.group)
        sign_in_as(member.user)

        expect { post group_event_registrations_path(event.group, event), params: { registration: { member_id: member.id } } }
          .not_to change(Registration, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
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

    context "when signed in as a stranger" do
      it "returns 404 and leaves the registration unchanged" do
        registration = create(:registration, status: "reserved")
        sign_in_as(create(:user))

        patch group_event_registration_path(registration.event.group, registration.event, registration), params: { registration: { status: "yes" } }

        expect(response).to have_http_status :not_found
        expect(registration.reload.status).to eq "reserved"
      end
    end

    context "when signed in as an active member" do
      it "updates the registration" do
        event = create(:event)
        registration = create(:registration, event:, member: create(:member, group: event.group))
        actor = create(:member, status: :active, group: event.group)
        sign_in_as(actor.user)

        patch group_event_registration_path(event.group, event, registration), params: { registration: { status: "yes" } }

        expect(response).to redirect_to group_event_registration_path(event.group, event, registration)
        expect(registration.reload.status).to eq "yes"
      end

      it "re-renders the edit page when the registration is invalid" do
        event = create(:event)
        registration = create(:registration, event:, member: create(:member, group: event.group))
        actor = create(:member, status: :active, group: event.group)
        sign_in_as(actor.user)

        patch group_event_registration_path(event.group, event, registration), params: { registration: { member_id: "" } }

        expect(response).to have_http_status :unprocessable_entity
      end

      it "ignores a posted event_id, leaving the registration on its own event" do
        event = create(:event)
        registration = create(:registration, event:, member: create(:member, group: event.group))
        original_event = registration.event
        other_event = create(:event)
        actor = create(:member, status: :active, group: event.group)
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

    context "when signed in as a stranger" do
      it "returns 404 and does not destroy the registration" do
        registration = create(:registration)
        sign_in_as(create(:user))

        expect { delete group_event_registration_path(registration.event.group, registration.event, registration) }
          .not_to change(Registration, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "destroys the registration" do
        event = create(:event)
        registration = create(:registration, event:, member: create(:member, group: event.group))
        actor = create(:member, status: :active, group: event.group)
        sign_in_as(actor.user)

        expect { delete group_event_registration_path(event.group, event, registration) }
          .to change(Registration, :count).by(-1)

        expect(response).to redirect_to group_event_registrations_path(event.group, event)
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

  # Registering somebody from another group publishes their name through Event#attendees to people
  # with no claim on it. The picker offers members_available; the parameter was unscoped.
  describe "a member_id belonging to another group" do
    it "is ignored, so the registration is not created" do
      event = create(:event)
      actor = create(:member, status: :active, group: event.group)
      outsider = create(:member)
      sign_in_as(actor.user)

      expect {
        post group_event_registrations_path(event.group, event),
          params: { registration: { member_id: outsider.id, status: :yes } }
      }.not_to change(Registration, :count)

      expect(event.reload.attendees).not_to include outsider
    end
  end
end
