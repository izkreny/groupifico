require 'rails_helper'

RSpec.describe "Events::Invitations", type: :request do
  describe "POST /groups/:group_id/events/:event_id/invitation" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        post group_event_invitation_path(event.group, event)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and invites nobody" do
        event = create(:event)
        sign_in_as(create(:user))

        expect { post group_event_invitation_path(event.group, event) }.not_to change(Registration, :count)
        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as a member holding no role" do
      it "refuses with a redirect carrying an alert, and invites nobody" do
        event = create(:event)
        member = create(:member, :active, group: event.group)
        sign_in_as(member.user)

        expect { post group_event_invitation_path(event.group, event) }.not_to change(Registration, :count)
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end

    context "when signed in as a members administrator" do
      it "refuses, because the invitation row does not mark that column" do
        event = create(:event)
        actor = create(:member, :active, :members_administrator, group: event.group)
        sign_in_as(actor.user)

        expect { post group_event_invitation_path(event.group, event) }.not_to change(Registration, :count)
        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a paused events administrator" do
      it "refuses, because inviting is a write" do
        event = create(:event)
        actor = create(:member, :paused, :events_administrator, group: event.group)
        sign_in_as(actor.user)

        expect { post group_event_invitation_path(event.group, event) }.not_to change(Registration, :count)
        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as the event's manager" do
      it "invites every active member still missing a registration" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, creator: actor, manager: actor)
        create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        post group_event_invitation_path(event.group, event)

        expect(event.registrations.invited.count).to eq 2
        expect(response).to redirect_to group_event_path(event.group, event)
        expect(flash[:notice]).to eq "2 members invited."
      end
    end

    context "when signed in as an events administrator" do
      it "invites the rest and changes nobody's existing registration" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group, creator: actor)
        held = create(:registration, event:, member: actor, status: :reserved)
        missing = create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        post group_event_invitation_path(event.group, event)

        expect(held.reload).to be_reserved
        expect(event.registrations.invited.pluck(:member_id)).to eq [ missing.id ]
      end

      it "says so when nobody was left to invite" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group, creator: actor)
        create(:registration, event:, member: actor, status: :yes)
        sign_in_as(actor.user)

        post group_event_invitation_path(event.group, event)

        expect(flash[:notice]).to eq "Nobody was left to invite."
      end
    end
  end

  describe "PATCH /groups/:group_id/events/:event_id/invitation" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        patch group_event_invitation_path(event.group, event)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        event = create(:event)
        sign_in_as(create(:user))

        patch group_event_invitation_path(event.group, event)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as a member holding no role" do
      it "refuses and leaves every held place as it was" do
        event = create(:event)
        member = create(:member, :active, group: event.group)
        held = create(:registration, event:, member:, status: :reserved)
        sign_in_as(member.user)

        patch group_event_invitation_path(event.group, event)

        expect(held.reload).to be_reserved
        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a paused events administrator" do
      it "refuses and leaves every held place as it was" do
        event = create(:event)
        actor = create(:member, :paused, :events_administrator, group: event.group)
        held = create(:registration, event:, member: actor, status: :reserved)
        sign_in_as(actor.user)

        patch group_event_invitation_path(event.group, event)

        expect(held.reload).to be_reserved
        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as the event's manager" do
      it "moves every held place to invited and returns to the events list" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, creator: actor, manager: actor)
        held = create(:registration, event:, member: actor, status: :reserved)
        sign_in_as(actor.user)

        patch group_event_invitation_path(event.group, event)

        expect(held.reload).to be_invited
        expect(response).to redirect_to group_events_path(event.group)
        expect(flash[:notice]).to eq "1 member invited."
      end
    end
  end
end
