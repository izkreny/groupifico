require 'rails_helper'

RSpec.describe "Registrations::Invitations", type: :request do
  describe "POST /groups/:group_id/events/:event_id/registrations/:registration_id/invitation" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        registration = create(:registration)

        post group_event_registration_invitation_path(registration.event.group, registration.event, registration)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        registration = create(:registration)
        sign_in_as(create(:user))

        post group_event_registration_invitation_path(registration.event.group, registration.event, registration)

        expect(response).to have_http_status :not_found
      end
    end

    context "when the registration belongs to another group's event" do
      it "returns 404 rather than reaching it through this group" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group, creator: actor)
        elsewhere = create(:registration, status: :reserved)
        sign_in_as(actor.user)

        post group_event_registration_invitation_path(event.group, event, elsewhere)

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

        post group_event_registration_invitation_path(event.group, event, held)

        expect(held.reload).to be_reserved
        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a paused events administrator" do
      it "refuses and leaves the held place as it was" do
        actor = create(:member, :paused, :events_administrator)
        event = create(:event, group: actor.group, creator: actor)
        held = create(:registration, event:, member: actor, status: :reserved)
        sign_in_as(actor.user)

        post group_event_registration_invitation_path(event.group, event, held)

        expect(held.reload).to be_reserved
        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as the event's manager" do
      it "moves a held place to invited" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, creator: actor, manager: actor)
        held = create(:registration, event:, member: create(:member, group: event.group), status: :reserved)
        sign_in_as(actor.user)

        post group_event_registration_invitation_path(event.group, event, held)

        expect(held.reload).to be_invited
        expect(response).to redirect_to group_event_path(event.group, event)
      end

      it "refuses to ask a paused member, and leaves their held place as it was" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, creator: actor, manager: actor)
        held = create(:registration, event:, member: create(:member, :paused, group: event.group), status: :reserved)
        sign_in_as(actor.user)

        post group_event_registration_invitation_path(event.group, event, held)

        expect(held.reload).to be_reserved
        expect(response).to redirect_to group_event_path(event.group, event)
        expect(flash[:alert]).to end_with "is paused, so they are not asked."
      end

      it "leaves an answer as it was, because a manager does not overrule one" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, creator: actor, manager: actor, status: :confirmed)
        answered = create(:registration, event:, member: create(:member, group: event.group), status: :no)
        sign_in_as(actor.user)

        post group_event_registration_invitation_path(event.group, event, answered)

        expect(answered.reload).to be_no
        expect(flash[:notice]).to end_with "was already asked."
      end
    end
  end
end
