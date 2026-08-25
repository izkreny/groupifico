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

    context "when successfully signed in" do
      it "shows the registrations page" do
        event = create(:event)
        sign_in_as(create(:user))

        get group_event_registrations_path(event.group, event)

        expect(response).to have_http_status :ok
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

    context "when successfully signed in" do
      it "shows the registration page" do
        registration = create(:registration)
        sign_in_as(create(:user))

        get group_event_registration_path(registration.event.group, registration.event, registration)

        expect(response).to have_http_status :ok
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

    context "when successfully signed in" do
      it "shows the new registration page" do
        event = create(:event)
        sign_in_as(create(:user))

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

    context "when successfully signed in" do
      it "shows the edit registration page" do
        registration = create(:registration)
        sign_in_as(create(:user))

        get edit_group_event_registration_path(registration.event.group, registration.event, registration)

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "POST /groups/:group_id/events/:event_id/registrations" do
    let(:event) { create(:event) }

    context "when not signed in" do
      it "redirects to the sign-in page" do
        member = create(:member, group: event.group)

        post group_event_registrations_path(event.group, event), params: { registration: { member_id: member.id } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "creates the registration" do
        member = create(:member, group: event.group)
        sign_in_as(member.user)

        expect { post group_event_registrations_path(event.group, event), params: { registration: { member_id: member.id } } }.to change(Registration, :count).by(1)
        expect(response).to redirect_to group_event_registration_path(event.group, event, Registration.sole)
      end

      it "re-renders the new page when the registration is invalid" do
        sign_in_as(create(:user))

        expect { post group_event_registrations_path(event.group, event), params: { registration: { member_id: "" } } }
          .not_to change(Registration, :count)

        expect(response).to have_http_status :unprocessable_entity
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

    context "when successfully signed in" do
      it "updates the registration" do
        registration = create(:registration)
        sign_in_as(create(:user))

        patch group_event_registration_path(registration.event.group, registration.event, registration), params: { registration: { status: "yes" } }

        expect(response).to redirect_to group_event_registration_path(registration.event.group, registration.event, registration)
        expect(registration.reload.status).to eq "yes"
      end

      it "re-renders the edit page when the registration is invalid" do
        registration = create(:registration)
        sign_in_as(create(:user))

        patch group_event_registration_path(registration.event.group, registration.event, registration), params: { registration: { member_id: "" } }

        expect(response).to have_http_status :unprocessable_entity
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

    context "when successfully signed in" do
      it "destroys the registration" do
        registration = create(:registration)
        sign_in_as(create(:user))

        expect { delete group_event_registration_path(registration.event.group, registration.event, registration) }
          .to change(Registration, :count).by(-1)

        expect(response).to redirect_to group_event_registrations_path(registration.event.group, registration.event)
      end
    end
  end
end
