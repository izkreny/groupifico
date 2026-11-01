require 'rails_helper'

RSpec.describe "Events::Rosters", type: :request do
  describe "GET /groups/:group_id/events/:event_id/roster/edit" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        get edit_group_event_roster_path(event.group, event)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        event = create(:event)
        sign_in_as(create(:user))

        get edit_group_event_roster_path(event.group, event)

        expect(response).to have_http_status :not_found
      end
    end

    # The registering row of the events table: a member holding no role answers for themselves on
    # the event's roster and never opens this screen.
    context "when signed in as a member holding no role" do
      it "refuses with a redirect carrying an alert" do
        event = create(:event)
        sign_in_as(create(:member, :active, group: event.group).user)

        get edit_group_event_roster_path(event.group, event)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end

    context "when signed in as the event's manager" do
      it "offers an unticked box for a member off the list" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)

        get edit_group_event_roster_path(event.group, event)

        box = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(actor, :tick)}")
        expect([ box["checked"], box["disabled"] ]).to eq [ nil, nil ]
      end

      it "draws a registered row's box ticked and disabled, says who can remove, and posts no listed id" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        registered = create(:registration, event:, member: create(:member, :active, group: event.group)).member
        sign_in_as(actor.user)

        get edit_group_event_roster_path(event.group, event)

        html = Nokogiri::HTML(response.body)
        box = html.at_css("##{ActionView::RecordIdentifier.dom_id(registered, :tick)}")
        expect([ box["checked"], box["disabled"] ]).to eq %w[ checked disabled ]
        expect(html.at_css("##{ActionView::RecordIdentifier.dom_id(registered)}").text).to include "only an administrator can remove"
        expect(html.css("input[name='listed_ids[]']").map { it["value"] }).to eq [ "" ]
      end
    end

    context "when signed in as an events administrator" do
      it "draws a registered row's box ticked and enabled, and posts its id as listed" do
        event = create(:event)
        registered = create(:member, :active, group: event.group)
        create(:registration, event:, member: registered)
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)

        get edit_group_event_roster_path(event.group, event)

        html = Nokogiri::HTML(response.body)
        box = html.at_css("##{ActionView::RecordIdentifier.dom_id(registered, :tick)}")
        expect([ box["checked"], box["disabled"] ]).to eq [ "checked", nil ]
        expect(html.css("input[name='listed_ids[]']").map { it["value"] }).to eq [ "", registered.id.to_s ]
      end

      # A paused or inactive member's registration has no other way off the list.
      it "draws a paused and an inactive member's registration so they can be removed" do
        event = create(:event)
        paused = create(:member, :paused, group: event.group)
        gone = create(:member, :inactive, group: event.group)
        create(:registration, event:, member: paused)
        create(:registration, event:, member: gone)
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)

        get edit_group_event_roster_path(event.group, event)

        expect(response.body).to include %(id="#{ActionView::RecordIdentifier.dom_id(paused, :tick)}"), %(id="#{ActionView::RecordIdentifier.dom_id(gone, :tick)}")
      end

      it "lists a paused member off the list with no checkbox, and omits an inactive one" do
        event = create(:event)
        paused = create(:member, :paused, group: event.group)
        gone = create(:member, :inactive, group: event.group)
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)

        get edit_group_event_roster_path(event.group, event)

        expect(response.body).to include %(id="#{ActionView::RecordIdentifier.dom_id(paused)}")
        expect(response.body).not_to include %(id="#{ActionView::RecordIdentifier.dom_id(paused, :tick)}")
        expect(response.body).not_to include %(id="#{ActionView::RecordIdentifier.dom_id(gone)}")
      end
    end
  end

  describe "PATCH /groups/:group_id/events/:event_id/roster" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)
        member = create(:member, group: event.group)

        patch group_event_roster_path(event.group, event), params: { member_ids: [ member.id ], listed_ids: [ "" ] }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and reserves nothing" do
        event = create(:event)
        member = create(:member, group: event.group)
        sign_in_as(create(:user))

        expect { patch group_event_roster_path(event.group, event), params: { member_ids: [ member.id ], listed_ids: [ "" ] } }
          .not_to change(Registration, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as a member holding no role" do
      it "refuses with a redirect carrying an alert, and reserves nothing" do
        event = create(:event)
        member = create(:member, :active, group: event.group)
        sign_in_as(member.user)

        expect { patch group_event_roster_path(event.group, event), params: { member_ids: [ member.id ], listed_ids: [ "" ] } }
          .not_to change(Registration, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and reserves nothing" do
        event = create(:event)
        member = create(:member, :paused, group: event.group)
        sign_in_as(member.user)

        expect { patch group_event_roster_path(event.group, event), params: { member_ids: [ member.id ], listed_ids: [ "" ] } }
          .not_to change(Registration, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end

    context "when signed in as the event's manager" do
      it "reserves a place for every ticked member, and asks nobody" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        first = create(:member, :active, group: actor.group)
        second = create(:member, :active, group: actor.group)
        sign_in_as(actor.user)

        patch group_event_roster_path(event.group, event), params: { member_ids: [ "", first.id, second.id ], listed_ids: [ "" ] }

        expect(event.registrations.pluck(:status)).to eq %w[ reserved reserved ]
        expect(response).to redirect_to group_event_path(event.group, event)
        expect(flash[:notice]).to eq "2 places reserved."
      end

      it "refuses a posted removal and writes nothing, the ticks beside it included" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        registered = create(:member, :active, group: event.group)
        create(:registration, event:, member: registered)
        ticked = create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        expect { patch group_event_roster_path(event.group, event), params: { member_ids: [ "", ticked.id ], listed_ids: [ "", registered.id ] } }
          .not_to change(Registration, :count)

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as an events administrator" do
      it "removes an unticked member's registration, an answer included" do
        event = create(:event, status: :confirmed, starts_at: 1.day.from_now, ends_at: 2.days.from_now)
        answered = create(:member, :active, group: event.group)
        create(:registration, event:, member: answered, status: :yes)
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)

        expect { patch group_event_roster_path(event.group, event), params: { member_ids: [ "" ], listed_ids: [ "", answered.id ] } }
          .to change(event.registrations, :count).by(-1)

        expect(flash[:notice]).to eq "1 place removed."
      end

      it "reserves and removes in one submit, and says how many of each" do
        event = create(:event)
        leaving = create(:member, :active, group: event.group)
        create(:registration, event:, member: leaving)
        first = create(:member, :active, group: event.group)
        second = create(:member, :active, group: event.group)
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)

        patch group_event_roster_path(event.group, event), params: { member_ids: [ "", first.id, second.id ], listed_ids: [ "", leaving.id ] }

        expect(event.registrations.pluck(:member_id)).to contain_exactly(first.id, second.id)
        expect(flash[:notice]).to eq "2 places reserved, 1 removed."
      end

      it "leaves a member registered while the form sat open, who it never drew" do
        event = create(:event)
        arrived = create(:member, :active, group: event.group)
        create(:registration, event:, member: arrived)
        ticked = create(:member, :active, group: event.group)
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)

        patch group_event_roster_path(event.group, event), params: { member_ids: [ "", ticked.id ], listed_ids: [ "" ] }

        expect(event.registrations.pluck(:member_id)).to contain_exactly(arrived.id, ticked.id)
      end

      it "leaves another event's registration alone, whatever is posted as listed" do
        event = create(:event)
        elsewhere = create(:registration, event: create(:event, group: event.group), member: create(:member, :active, group: event.group))
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)

        patch group_event_roster_path(event.group, event), params: { member_ids: [ "" ], listed_ids: [ "", elsewhere.member_id ] }

        expect(Registration.exists?(elsewhere.id)).to be true
      end

      # The two ways of changing nothing, which differ only in the message: this one asked for no change.
      it "re-renders the screen when nothing changed" do
        event = create(:event)
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)

        expect { patch group_event_roster_path(event.group, event), params: { member_ids: [ "" ], listed_ids: [ "" ] } }
          .not_to change(Registration, :count)

        expect(response).to have_http_status :unprocessable_content
        expect(flash[:alert]).to include "Tick or untick"
      end

      it "ignores a ticked member who is paused, inactive or already registered" do
        event = create(:event)
        paused = create(:member, :paused, group: event.group)
        gone = create(:member, :inactive, group: event.group)
        registered = create(:member, :active, group: event.group)
        create(:registration, event:, member: registered)
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)

        expect { patch group_event_roster_path(event.group, event), params: { member_ids: [ paused.id, gone.id, registered.id ], listed_ids: [ "" ] } }
          .not_to change(Registration, :count)

        expect(flash[:alert]).to include "Nothing changed"
      end

      # The row the intersection cannot see: it lands after `available_members` has read the set and reaches
      # the unique index instead. The racing row rolls back with the rest here, where a real one on
      # another connection would not, so what this proves is the answer rather than the row count.
      it "answers the screen again when somebody is registered mid-request" do
        event = create(:event)
        available = create(:member, :active, group: event.group)
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)

        racing_on(event) do
          patch group_event_roster_path(event.group, event), params: { member_ids: [ available.id ], listed_ids: [ "" ] }
        end

        expect(response).to have_http_status :unprocessable_content
        expect(flash[:alert]).to include "Nothing changed"
      end

      it "ignores a ticked member from another group, whose name is nobody here's to publish" do
        event = create(:event)
        outsider = create(:member, :active)
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)

        expect { patch group_event_roster_path(event.group, event), params: { member_ids: [ outsider.id ], listed_ids: [ "" ] } }
          .not_to change(Registration, :count)

        expect(event.registrations.where(member: outsider)).to be_empty
      end
    end
  end

  # Runs the block with the row the request is about to write already landing from inside the
  # request, after `available_members` has read the set, which is the only place a spec can reach that
  # window. The lambda is held in a local so `skip_callback` is handed the object `set_callback`
  # was given.
  def racing_on(event)
    insert = ->(registration) {
      Registration.insert_all!([ { event_id: event.id, member_id: registration.member_id,
        status: Registration.statuses[:reserved], created_at: Time.current, updated_at: Time.current } ])
    }

    Registration.set_callback(:create, :before, insert)
    yield
  ensure
    Registration.skip_callback(:create, :before, insert)
  end
end
