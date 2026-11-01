require 'rails_helper'

RSpec.describe "Events::Reservations", type: :request do
  describe "POST /groups/:group_id/events/:event_id/reservation" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        post group_event_reservation_path(event.group, event)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and reserves nothing" do
        event = create(:event)
        sign_in_as(create(:user))

        expect { post group_event_reservation_path(event.group, event) }.not_to change(Registration, :count)
        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as a member holding no role" do
      it "refuses with a redirect carrying an alert, and reserves nothing" do
        event = create(:event)
        member = create(:member, :active, group: event.group)
        sign_in_as(member.user)

        expect { post group_event_reservation_path(event.group, event) }.not_to change(Registration, :count)
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end

    context "when signed in as a members administrator" do
      it "refuses, because the registering row does not mark that column" do
        event = create(:event)
        actor = create(:member, :active, :members_administrator, group: event.group)
        sign_in_as(actor.user)

        expect { post group_event_reservation_path(event.group, event) }.not_to change(Registration, :count)
        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a paused events administrator" do
      it "refuses, because reserving is a write" do
        event = create(:event)
        actor = create(:member, :paused, :events_administrator, group: event.group)
        sign_in_as(actor.user)

        expect { post group_event_reservation_path(event.group, event) }.not_to change(Registration, :count)
        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as the event's manager" do
      it "reserves a place for every active member off the list, and asks nobody" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, creator: actor, manager: actor)
        create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        post group_event_reservation_path(event.group, event)

        expect(event.registrations.pluck(:status)).to eq %w[ reserved reserved ]
        expect(response).to redirect_to group_event_path(event.group, event)
        expect(flash[:notice]).to eq "2 places reserved."
      end
    end

    context "when signed in as an events administrator" do
      it "says so when nobody was left to add" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group, creator: actor)
        create(:registration, event:, member: actor, status: :reserved)
        sign_in_as(actor.user)

        post group_event_reservation_path(event.group, event)

        expect(flash[:notice]).to eq "Nobody was left to add."
      end
    end
  end
end
