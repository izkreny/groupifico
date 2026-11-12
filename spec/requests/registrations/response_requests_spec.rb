require 'rails_helper'

RSpec.describe "Registrations::ResponseRequests", type: :request do
  describe "POST /groups/:group_id/events/:event_id/registrations/:registration_id/response_request" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        registration = create(:registration)

        post group_event_registration_response_request_path(registration.event.group, registration.event, registration)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        registration = create(:registration)
        sign_in_as(create(:user))

        post group_event_registration_response_request_path(registration.event.group, registration.event, registration)

        expect(response).to have_http_status :not_found
      end
    end

    context "when the registration belongs to another group's event" do
      it "returns 404 rather than reaching it through this group" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group, creator: actor)
        elsewhere = create(:registration, status: :reserved)
        sign_in_as(actor.user)

        post group_event_registration_response_request_path(event.group, event, elsewhere)

        expect(response).to have_http_status :not_found
        expect(elsewhere.reload).to be_reserved
      end
    end

    context "when signed in as a member holding no role" do
      it "refuses and leaves the held place as it was" do
        member = create(:member, :active)
        event = create(:event, group: member.group, creator: member)
        held = create(:registration, event:, member:, status: :reserved)
        sign_in_as(member.user)

        post group_event_registration_response_request_path(event.group, event, held)

        expect(held.reload).to be_reserved
        expect(response).to redirect_to root_path
      end

      it "emails nobody" do
        member = create(:member, :active)
        event = create(:event, group: member.group, creator: member)
        held = create(:registration, event:, member:, status: :reserved)
        sign_in_as(member.user)

        expect { post group_event_registration_response_request_path(event.group, event, held) }.not_to have_enqueued_mail(RegistrationMailer, :response_requested)
      end
    end

    context "when signed in as a paused events administrator" do
      it "refuses and leaves the held place as it was" do
        actor = create(:member, :paused, :events_administrator)
        event = create(:event, group: actor.group, creator: actor)
        held = create(:registration, event:, member: actor, status: :reserved)
        sign_in_as(actor.user)

        post group_event_registration_response_request_path(event.group, event, held)

        expect(held.reload).to be_reserved
        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as the event's manager" do
      it "moves a held place to response_requested" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, creator: actor, manager: actor)
        held = create(:registration, event:, member: create(:member, group: event.group), status: :reserved)
        sign_in_as(actor.user)

        post group_event_registration_response_request_path(event.group, event, held)

        expect(held.reload).to be_response_requested
        expect(response).to redirect_to group_event_path(event.group, event)
      end

      it "refuses to request a response from a paused member, and leaves their held place as it was" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, creator: actor, manager: actor)
        held = create(:registration, event:, member: create(:member, :paused, group: event.group), status: :reserved)
        sign_in_as(actor.user)

        post group_event_registration_response_request_path(event.group, event, held)

        expect(held.reload).to be_reserved
        expect(response).to redirect_to group_event_path(event.group, event)
        expect(flash[:alert]).to end_with "is paused, so no response was requested."
      end

      it "refuses on a concluded event with an alert, and leaves the held place as it was" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, creator: actor, manager: actor, status: :concluded)
        held = create(:registration, event:, member: create(:member, :active, group: event.group), status: :reserved)
        sign_in_as(actor.user)

        post group_event_registration_response_request_path(event.group, event, held)

        expect(held.reload).to be_reserved
        expect(flash[:alert]).to eq "This event is concluded, so no response was requested."
      end

      it "leaves an answer as it was, because a manager does not overrule one" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, creator: actor, manager: actor, status: :confirmed)
        answered = create(:registration, event:, member: create(:member, group: event.group), status: :no)
        sign_in_as(actor.user)

        post group_event_registration_response_request_path(event.group, event, answered)

        expect(answered.reload).to be_no
      end

      # WHY: #431 AC2, the tinted plane's Send again posts here, and asking again is what a press on a requested row does.
      it "asks a member who has a question waiting again, and keeps their row requested" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, creator: actor, manager: actor)
        requested = travel_to(Time.zone.parse("2026-11-10 09:00")) { create(:registration, event:, member: create(:member, :active, group: event.group), status: :response_requested) }
        sign_in_as(actor.user)

        travel_to Time.zone.parse("2026-11-12 14:05") do
          expect { post group_event_registration_response_request_path(event.group, event, requested) }.to have_enqueued_mail(RegistrationMailer, :response_requested).with(requested).once
        end

        expect(requested.reload).to be_response_requested
        expect(requested.updated_at).to eq Time.zone.parse("2026-11-12 14:05")
        expect(flash[:notice]).to eq "#{requested.member.full_name}'s response was requested again."
      end
    end
  end
end
