require 'rails_helper'

RSpec.describe "Events::RosterOrders", type: :request do
  describe "PATCH /groups/:group_id/events/:event_id/roster_order" do
    context "when not signed in" do
      it "redirects to the sign-in page and keeps no order" do
        event = create(:event)

        patch group_event_roster_order_path(event.group, event, order: "status")

        expect(response).to redirect_to new_session_path
        expect(cookies[:roster_order]).to be_nil
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and keeps no order" do
        event = create(:event)
        sign_in_as(create(:user))

        patch group_event_roster_order_path(event.group, event, order: "status")

        expect(response).to have_http_status :not_found
        expect(cookies[:roster_order]).to be_nil
      end
    end

    context "when signed in as a member holding no role" do
      it "keeps the order chosen and returns to the event" do
        event = create(:event)
        member = create(:member, :active, group: event.group)
        sign_in_as(member.user)

        patch group_event_roster_order_path(event.group, event, order: "status")

        expect(response).to redirect_to group_event_path(event.group, event)
        expect(cookies[:roster_order]).to eq "status"
      end

      it "keeps the direction chosen with the order" do
        event = create(:event)
        member = create(:member, :active, group: event.group)
        sign_in_as(member.user)

        patch group_event_roster_order_path(event.group, event, order: "name", descending: true)

        expect([ cookies[:roster_order], cookies[:roster_descending] ]).to eq %w[ name true ]
      end

      it "keeps nothing for an order the list does not offer" do
        event = create(:event)
        member = create(:member, :active, group: event.group)
        sign_in_as(member.user)

        patch group_event_roster_order_path(event.group, event, order: "created_at")

        expect(response).to redirect_to group_event_path(event.group, event)
        expect(cookies[:roster_order]).to be_nil
      end
    end
  end
end
