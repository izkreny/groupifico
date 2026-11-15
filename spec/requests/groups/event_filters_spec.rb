require "rails_helper"

RSpec.describe "Groups::EventFilters", type: :request do
  describe "PATCH /groups/:group_id/event_filter" do
    context "when not signed in" do
      it "redirects to the sign-in page and keeps nothing" do
        group = create(:group)

        patch group_event_filter_path(group, scope: "past")

        expect(response).to redirect_to new_session_path
        expect(cookies[:events_list]).to be_nil
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and keeps nothing" do
        group = create(:group)
        sign_in_as(create(:user))

        patch group_event_filter_path(group, scope: "past")

        expect(response).to have_http_status :not_found
        expect(cookies[:events_list]).to be_nil
      end
    end

    context "when signed in as a member holding no role" do
      # WHY: #460 AC9. What a member applies is what their next visit to the list shows.
      it "keeps the list and filters applied and returns to the events list" do
        member = create(:member, :active)
        sign_in_as(member.user)

        patch group_event_filter_path(member.group, scope: "past", category: %w[ gig ], answer: %w[ yes not_answered ])

        expect(response).to redirect_to group_events_path(member.group)
        expect([ cookies[:events_list], cookies[:events_categories], cookies[:events_answers] ]).to eq %w[ past gig yes,not_answered ]
      end

      # WHY: #460 AC11. A value the sheet does not offer is dropped rather than stored, the managed filter included for someone who manages nothing.
      it "keeps nothing the sheet does not offer" do
        member = create(:member, :active)
        sign_in_as(member.user)

        patch group_event_filter_path(member.group, scope: "archived", category: %w[ party ], managed: "1")

        expect(response).to redirect_to group_events_path(member.group)
        expect([ cookies[:events_list], cookies[:events_categories], cookies[:events_managed] ]).to all be_blank
      end

      # A chip's ✕ applies everything else that was on, so the filter it removes has to go from the cookies too.
      it "clears a filter that is no longer applied" do
        member = create(:member, :active)
        sign_in_as(member.user)
        patch group_event_filter_path(member.group, category: %w[ gig ])

        patch group_event_filter_path(member.group)

        expect(cookies[:events_categories]).to be_blank
      end
    end
  end
end
