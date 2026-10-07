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

      # The events list and the group home draw the same Next up card, so pressing it there lands
      # back there rather than on the event.
      it "returns to the page it was pressed on" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, creator: actor, manager: actor)
        create(:registration, event:, member: actor, status: :reserved)
        sign_in_as(actor.user)

        post group_event_invitation_path(event.group, event), headers: { "HTTP_REFERER" => group_url(event.group) }

        expect(response).to redirect_to group_url(event.group)
      end
    end

    context "when signed in as an events administrator" do
      it "asks a held place and a member with none alike, and leaves an answer as it was" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group, creator: actor, status: :confirmed)
        held = create(:registration, event:, member: actor, status: :reserved)
        answered = create(:registration, event:, member: create(:member, :active, group: event.group), status: :maybe)
        missing = create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        post group_event_invitation_path(event.group, event)

        expect([ held.reload.status, answered.reload.status ]).to eq %w[ invited maybe ]
        expect(event.registrations.invited.pluck(:member_id)).to contain_exactly(actor.id, missing.id)
        expect(flash[:notice]).to eq "2 members invited."
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
end
