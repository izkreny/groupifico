require 'rails_helper'

RSpec.describe "Events", type: :request do
  describe "GET /groups/:group_id/events" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get group_events_path(create(:group))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        sign_in_as(create(:user))

        get group_events_path(create(:group))

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the events page" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response).to have_http_status :ok
      end

      # WHY: the list menu is the screen's title as well as its filter, so what proves the title is there is the menu naming the open list and linking every list, rather than a heading above them.
      it "titles the screen with the menu that links the lists, the open one marked" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_events_path(member.group)

        menu = Nokogiri::HTML(response.body).at_css("details#scope")
        expect(menu.at_css("summary").text.squish).to eq "Upcoming events"
        expect(menu.css("a").map { [ it.text, it[:href], it["aria-current"] ] }).to eq [ [ "Upcoming events", group_events_path(member.group), "true" ], [ "Past events", group_events_path(member.group, scope: "past"), nil ], [ "Canceled events", group_events_path(member.group, scope: "canceled"), nil ] ]
      end

      # Who may create an event is `EventPolicy#create?`, and a refused reader gets no control
      # rather than a disabled one - so the assertion is the route's absence, not a class.
      it "offers the New event button to a reader who may create events" do
        owner = create(:member, :owner)
        sign_in_as(owner.user)

        get group_events_path(owner.group)

        expect(Nokogiri::HTML(response.body).at_css("a[href='#{new_group_event_path(owner.group)}']").text.strip).to eq "New event"
      end

      it "offers a plain member no New button" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response.body).not_to include %(href="#{new_group_event_path(member.group)}")
      end

      # `:from_the_future` rather than the bare factory, whose `starts_at` is a random point in a
      # year either side of today: this list shows the upcoming events, so half of those rolls put
      # the event this example is looking for on the other list.
      #
      # `status:` is named on top of the trait, which rolls its own: a confirmed roll makes the
      # event `Group#featured_event`, and it then draws as the hero rather than as a row. And the match
      # carries `id="` so the hero could not satisfy it if it did - `dom_id` alone is a substring
      # of the hero's `next_up_event_N`, which is what let the roll go unnoticed.
      it "lists only events from groups the acting user belongs to" do
        member = create(:member, :active)
        own_event = create(:event, :from_the_future, status: :unconfirmed, group: member.group, creator: member)
        other_event = create(:event, :from_the_future, status: :unconfirmed)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response.body).to include %(id="#{ActionView::RecordIdentifier.dom_id(own_event)}")
        expect(response.body).not_to include %(id="#{ActionView::RecordIdentifier.dom_id(other_event)}")
      end
    end

    # The create row of the events table marks `owner`, `administrator` and `events_administrator`,
    # and leaves `members_administrator` and `manager` blank; the owner and the plain member are
    # proven above.
    context "when signed in as an administrator" do
      it "offers the New button" do
        actor = create(:member, :active, :administrator)
        sign_in_as(actor.user)

        get group_events_path(actor.group)

        expect(response.body).to include %(href="#{new_group_event_path(actor.group)}")
      end
    end

    context "when signed in as an events administrator" do
      # Frame 4h's pencil, on the hero card and on the row beneath it alike.
      it "offers an Edit button on the hero card and on each row" do
        actor = create(:member, :active, :events_administrator)
        next_up = confirmed_event(actor, name: "Tuesday rehearsal", days: 2)
        later = confirmed_event(actor, name: "Sunday service", days: 5)
        sign_in_as(actor.user)

        get group_events_path(actor.group)

        html = Nokogiri::HTML(response.body)
        expect(html.at_css("##{ActionView::RecordIdentifier.dom_id(next_up, :next_up)} a[href='#{edit_group_event_path(actor.group, next_up)}'][aria-label='Edit Tuesday rehearsal']")).to be_present
        expect(html.at_css("##{ActionView::RecordIdentifier.dom_id(later)} a[href='#{edit_group_event_path(actor.group, later)}'][aria-label='Edit Sunday service']")).to be_present
      end

      # Duplicate leads Edit on the hero, as on the event screen.
      it "offers Duplicate before Edit on the hero card" do
        actor = create(:member, :active, :events_administrator)
        next_up = confirmed_event(actor, name: "Tuesday rehearsal", days: 2)
        sign_in_as(actor.user)

        get group_events_path(actor.group)

        labels = Nokogiri::HTML(response.body).css("##{ActionView::RecordIdentifier.dom_id(next_up, :next_up)} a[aria-label]").map { it["aria-label"] }
        expect(labels).to eq [ "Duplicate Tuesday rehearsal", "Edit Tuesday rehearsal" ]
      end

      it "offers the New button" do
        actor = create(:member, :active, :events_administrator)
        sign_in_as(actor.user)

        get group_events_path(actor.group)

        expect(response.body).to include %(href="#{new_group_event_path(actor.group)}")
      end

      it "offers no New button while the member is paused" do
        actor = create(:member, :paused, :events_administrator)
        sign_in_as(actor.user)

        get group_events_path(actor.group)

        expect(response.body).not_to include %(href="#{new_group_event_path(actor.group)}")
      end
    end

    context "when signed in as a members administrator" do
      it "offers no New button" do
        actor = create(:member, :active, :members_administrator)
        sign_in_as(actor.user)

        get group_events_path(actor.group)

        expect(response.body).not_to include %(href="#{new_group_event_path(actor.group)}")
      end
    end

    # Managing one event is a grant on that event alone, never on making new ones.
    context "when signed in as the manager of an event" do
      # A per-event grant, so the pencil shows on their event and on no other.
      it "offers an Edit button on the event they manage alone" do
        actor = create(:member, :active)
        create(:event, group: actor.group, manager: actor, name: "Ours", starts_at: 2.days.from_now)
        create(:event, group: actor.group, name: "Theirs", starts_at: 5.days.from_now)
        sign_in_as(actor.user)

        get group_events_path(actor.group)

        expect(Nokogiri::HTML(response.body).css("a[aria-label^='Edit ']").map { it["aria-label"] }).to eq [ "Edit Ours" ]
      end

      # `duplicate` authorizes `create?`, which managing an event does not grant.
      it "offers Edit alone on the hero card of the event they manage" do
        actor = create(:member, :active)
        create(:event, group: actor.group, manager: actor, name: "Ours", status: :confirmed, starts_at: 2.days.from_now)
        sign_in_as(actor.user)

        get group_events_path(actor.group)

        expect(Nokogiri::HTML(response.body).css("[id^=next_up] a[aria-label]").map { it["aria-label"] }).to eq [ "Edit Ours" ]
      end

      it "offers no New button" do
        actor = create(:member, :active)
        create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)

        get group_events_path(actor.group)

        expect(response.body).not_to include %(href="#{new_group_event_path(actor.group)}")
      end
    end

    # Times are frozen because the card states the distance to the event in words, so "in 2 days"
    # would otherwise depend on how long the suite takes to reach this file. What the freeze does
    # not do is decide which hour it stops at, which is `confirmed_event`'s job below.
    context "when the group has a next event" do
      # The hero card, one row beneath it and the reader's own answer row: the three pieces the
      # event card partials draw, asserted here rather than in a view spec because what a reader
      # sees on this screen is the response's own text.
      it "links the hero card's responses to the event with its roster open" do
        freeze_time do
          owner = create(:member, :owner)
          next_up = confirmed_event(owner, days: 2)
          create(:registration, event: next_up, member: owner, status: :yes)
          sign_in_as(owner.user)

          get group_events_path(owner.group)

          link = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(next_up, :next_up)} a[href='#{group_event_path(owner.group, next_up, responses: "show")}']")
          expect(link&.text&.squish).to eq "Who’s coming?"
        end
      end

      it "draws the hero card, a row beneath it and the question for an owner whose response is requested" do
        freeze_time do
          owner = create(:member, :owner)
          next_up = confirmed_event(owner, name: "Tuesday rehearsal", category: :rehearsal, days: 2)
          later = confirmed_event(owner, name: "Sunday service", days: 5)
          create(:registration, event: next_up, member: owner, status: :response_requested)
          sign_in_as(owner.user)

          get group_events_path(owner.group)

          expect(response.body).to include "Next up · in 2 days", "Tuesday rehearsal", "Confirmed rehearsal", "Are you coming?"
          expect(response.body).to include ActionView::RecordIdentifier.dom_id(later)
        end
      end

      it "offers a plain member no Edit button" do
        freeze_time do
          member = create(:member, :active)
          confirmed_event(member, days: 2)
          confirmed_event(member, days: 5)
          sign_in_as(member.user)

          get group_events_path(member.group)

          expect(Nokogiri::HTML(response.body).css("a[aria-label^='Edit ']")).to be_empty
        end
      end

      it "draws the answer and the counts for a plain member who has answered" do
        freeze_time do
          member = create(:member, :active, user: create(:user, :with_full_profile, first_name: "Carla", last_name: "Dean"))
          next_up = confirmed_event(member, days: 2)
          create(:registration, event: next_up, member:, status: :yes)
          sign_in_as(member.user)

          get group_events_path(member.group)

          expect(response.body).to include "Are you coming?", "no reply"
        end
      end

      # Where the question stands, which is the one thing about it this screen decides: inside the
      # hero's own card, and again under any row with the reader's response requested. `id="events"` is the
      # list's wrapper, so a match that crosses it has one copy on each side of the list's start.
      #
      # The count is what makes the order mean anything. Either copy alone satisfies the match on
      # its own, which is what the screen looked like when the answer row sat once below the list.
      it "puts the question inside the hero card and again under a requested row" do
        owner = create(:member, :owner)
        next_up = confirmed_event(owner, days: 2, name: "Tuesday rehearsal")
        later = confirmed_event(owner, days: 5, name: "Sunday service")
        create(:registration, event: next_up, member: owner, status: :response_requested)
        create(:registration, event: later, member: owner, status: :response_requested)
        sign_in_as(owner.user)

        get group_events_path(owner.group)

        expect(response.body).to match(/Tuesday rehearsal.*Are you coming\?.*id="events".*Sunday service.*Are you coming\?/m)
        expect(response.body.scan("Are you coming?").size).to eq 2
      end

      # The row's own answer is an icon and nothing else, so what it carries is the icon's name.
      # The clock is left alone here, unlike the examples around it: this one asserts no copy that
      # states a distance in time, and every event it creates is upcoming at whatever hour it runs.
      it "shows the reader's answer as an icon on a compact row, and nothing where there is none" do
        member = create(:member, :active)
        confirmed_event(member, days: 2)
        answered_row = confirmed_event(member, days: 5)
        requested_row = confirmed_event(member, days: 7)
        create(:registration, event: answered_row, member:, status: :maybe)
        create(:registration, event: requested_row, member:, status: :response_requested)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response.body).to include "you said maybe"
        expect(response.body).not_to include "you said response_requested"
      end

      # A reserved place puts no question, so the row says where the reader stands by the icon alone.
      it "shows a reserved place as an icon on a compact row, with nothing to answer" do
        member = create(:member, :active)
        confirmed_event(member, days: 2)
        reserved_row = confirmed_event(member, days: 5)
        create(:registration, event: reserved_row, member:, status: :reserved)
        sign_in_as(member.user)

        get group_events_path(member.group)

        row = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(reserved_row)}")
        expect([ row.css("svg[aria-label='Place reserved, no response requested yet']").size, row.css("form").size ]).to eq [ 1, 0 ]
      end

      # The pills themselves rather than the copy above them: three forms, one target, one value
      # each, and the reader's own answer lit. Without this the header carried both the positive
      # and the negative assertion, so a card with no pills under it read as correct.
      #
      # The lit pill is matched by the class and the label in one tag rather than by the class
      # alone, which any of the three carrying it would satisfy - so inverting the condition that
      # lights it lights the other two and this still reddens. It stops at `</button>` and claims
      # nothing about what follows: `button_to` puts its CSRF token there, empty only because this
      # environment has forgery protection off.
      # The clock is left alone, as in the row example: nothing here reads it.
      it "draws the three pills as forms writing the reader's own registration" do
        member = create(:member, :active)
        next_up = confirmed_event(member, days: 2)
        registration = create(:registration, event: next_up, member:, status: :maybe)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response.body).to include %(action="#{group_event_registration_path(member.group, next_up, registration)}")
        expect(response.body).to include %(name="_method" value="patch")
        expect(response.body).to include %(name="registration[status]" value="yes"), %(name="registration[status]" value="maybe"), %(name="registration[status]" value="no")
        expect(response.body).to match %r{btn-warning[^>]*>\s*<svg.*?</svg>\s*Maybe\s*</button>}m
      end

      it "leaves the pills out for a paused member, who may not write an answer" do
        freeze_time do
          member = create(:member, :paused)
          next_up = confirmed_event(member, days: 2)
          registration = create(:registration, event: next_up, member:, status: :response_requested)
          sign_in_as(member.user)

          get group_events_path(member.group)

          expect(response.body).to include "Next up · in 2 days"
          expect(response.body).not_to include "Are you coming?"
          expect(response.body).not_to include %(action="#{group_event_registration_path(member.group, next_up, registration)}")
        end
      end

      # Both halves of the no-response-requested state in one example, because they are one behaviour: the
      # tags are absent and a sentence stands where they were. The negative alone was satisfied by
      # a card that drew nothing there at all, which is what this state used to look like.
      it "says no response is requested while every registration is still reserved" do
        freeze_time do
          owner = create(:member, :owner)
          next_up = confirmed_event(owner, days: 2)
          create(:registration, event: next_up, member: owner, status: :reserved)
          sign_in_as(owner.user)

          get group_events_path(owner.group)

          expect(response.body).to include "Next up · in 2 days", "No responses requested yet · 1 on the list"
          expect(response.body).not_to include "no reply"
        end
      end

      it "offers Request responses while every registration is still reserved" do
        freeze_time do
          owner = create(:member, :owner)
          next_up = confirmed_event(owner, days: 2)
          create(:registration, event: next_up, member: owner, status: :reserved)
          sign_in_as(owner.user)

          get group_events_path(owner.group)

          expect(response.body).to include "Request responses", group_event_response_request_path(owner.group, next_up)
        end
      end

      it "offers no Request responses once a response has been requested" do
        freeze_time do
          owner = create(:member, :owner)
          next_up = confirmed_event(owner, days: 2)
          create(:registration, event: next_up, member: owner, status: :response_requested)
          create(:registration, event: next_up, member: create(:member, group: owner.group), status: :reserved)
          sign_in_as(owner.user)

          get group_events_path(owner.group)

          expect(response.body).to include "Next up · in 2 days"
          expect(response.body).not_to include "Request responses"
        end
      end

      # "Every registration is reserved" holds of an empty list, which has nobody to request from.
      it "offers no Request responses while nobody is on the list" do
        freeze_time do
          owner = create(:member, :owner)
          confirmed_event(owner, days: 2)
          sign_in_as(owner.user)

          get group_events_path(owner.group)

          expect(response.body).to include "Next up · in 2 days"
          expect(response.body).not_to include "Request responses"
        end
      end

      # Requesting moves active members' held places only, so a paused member's place leaves the button nothing to do.
      it "offers no Request responses while the only place held is a paused member's" do
        freeze_time do
          owner = create(:member, :owner)
          next_up = confirmed_event(owner, days: 2)
          create(:registration, event: next_up, member: create(:member, :paused, group: owner.group), status: :reserved)
          sign_in_as(owner.user)

          get group_events_path(owner.group)

          expect(response.body).to include "Next up · in 2 days"
          expect(response.body).not_to include "Request responses"
        end
      end

      it "offers a plain member no Request responses" do
        freeze_time do
          member = create(:member, :active)
          next_up = confirmed_event(member, days: 2)
          create(:registration, event: next_up, member:, status: :reserved)
          sign_in_as(member.user)

          get group_events_path(member.group)

          expect(response.body).to include "No responses requested yet · 1 on the list"
          expect(response.body).not_to include "Request responses"
        end
      end
    end

    # A negative offset is what makes an event past: `confirmed_event` reads `days:` as a distance
    # from now in either direction, and an event that started nine days ago ended eight days and
    # twenty-two hours ago, which is what `Event.past` reads.
    context "when the past list is requested" do
      it "lists the group's past events newest first, with no hero card" do
        member = create(:member, :active)
        confirmed_event(member, days: 2, name: "Tuesday rehearsal")
        confirmed_event(member, days: -9, name: "Spring concert")
        confirmed_event(member, days: -2, name: "Summer gig")
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "past")

        expect(response.body).to match(/Summer gig.*Spring concert/m)
        expect(response.body).not_to include "Next up", "Tuesday rehearsal"
      end

      # An event that has ended and that nobody concluded is still worth a roster, so the question
      # is put here too - in the tense the event is in. Both halves in one example: the past
      # tense present and the present tense absent, since a screen saying neither would satisfy
      # either assertion alone.
      it "puts the question in the past tense under an event that has ended" do
        member = create(:member, :active)
        over = confirmed_event(member, days: -9, name: "Spring concert")
        create(:registration, event: over, member:, status: :response_requested)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "past")

        expect(response.body).to include "Spring concert", "Did you go?"
        expect(response.body).not_to include "Are you coming?"
      end

      it "puts no question under an event somebody has concluded" do
        member = create(:member, :active)
        over = create(:event, group: member.group, creator: member, status: :concluded,
          name: "Summer gig", starts_at: 9.days.ago, ends_at: 9.days.ago + 2.hours)
        create(:registration, event: over, member:, status: :response_requested)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "past")

        expect(response.body).to include "Summer gig"
        expect(response.body).not_to include "Did you go?", "Are you coming?"
      end

      # Once an event has ended, whoever has not said yes or no has a response due, a held place included.
      it "puts whether they went to a held place and a question, with yes and no only" do
        member = create(:member, :active)
        held = confirmed_event(member, days: -9, name: "Spring concert")
        requested = confirmed_event(member, days: -6, name: "Summer gig")
        create(:registration, event: held, member:, status: :reserved)
        create(:registration, event: requested, member:, status: :response_requested)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "past")

        expect(response.body.scan("Did you go?").size).to eq 2
        expect(response.body).to include %(name="registration[status]" value="yes"), %(name="registration[status]" value="no")
        expect(response.body).not_to include %(name="registration[status]" value="maybe")
      end

      # The maybe is written the day before the event started, because an ended event takes no maybe.
      it "puts the question again to whoever said maybe before the event" do
        member = create(:member, :active)
        unsure = confirmed_event(member, days: -3, name: "Autumn fair")
        travel_to(unsure.starts_at - 1.day) { create(:registration, event: unsure, member:, status: :maybe) }
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "past")

        expect(response.body).to include "Autumn fair", "Did you go?"
        expect(response.body).not_to include %(name="registration[status]" value="maybe")
      end

      it "leaves a yes given before the event standing, with no second question" do
        member = create(:member, :active)
        over = confirmed_event(member, days: -9, name: "Spring concert")
        create(:registration, event: over, member:, status: :yes)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "past")

        expect(response.body).to include "Spring concert", "you said yes"
        expect(response.body).not_to include "Did you go?"
      end

      # The list menu states which list is open, so a reader who lands on the past one by a typed URL
      # sees the control agreeing with what is under it.
      it "names the past list in the list menu and marks its link" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "past")

        menu = Nokogiri::HTML(response.body).at_css("details#scope")
        expect([ menu.at_css("summary").text.squish, menu.at_css("a[aria-current]").text ]).to eq [ "Past events", "Past events" ]
      end

      # WHY: a scope naming no list is the upcoming list, which is what keeps a mistyped URL a screen rather than an error, with the pill agreeing with what is under it.
      it "reads an unknown scope as the upcoming list" do
        member = create(:member, :active)
        confirmed_event(member, days: -2, name: "Summer gig")
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "sideways")

        expect(Nokogiri::HTML(response.body).at_css("details#scope summary").text.squish).to eq "Upcoming events"
        expect(response.body).not_to include "Summer gig"
      end
    end

    # WHY: `confirmed_event` and then the status, because a registration takes an answer only while its event is open to answers, so a member answers before the event is called off.
    context "when the canceled list is requested" do
      it "lists the group's canceled events newest first, whatever their dates, with no hero card" do
        member = create(:member, :active)
        confirmed_event(member, days: 2, name: "Tuesday rehearsal")
        confirmed_event(member, days: -9, name: "Spring concert").update!(status: :canceled)
        confirmed_event(member, days: 4, name: "Autumn gig").update!(status: :canceled)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "canceled")

        expect(response.body).to match(/Autumn gig.*Spring concert/m)
        expect(response.body).not_to include "Next up", "Tuesday rehearsal"
      end

      it "names the canceled list in the list menu and marks its link" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "canceled")

        menu = Nokogiri::HTML(response.body).at_css("details#scope")
        expect([ menu.at_css("summary").text.squish, menu.at_css("a[aria-current]").text ]).to eq [ "Canceled events", "Canceled events" ]
      end

      it "shows the answer a member gave" do
        member = create(:member, :active)
        answered = confirmed_event(member, days: -9, name: "Spring concert")
        create(:registration, event: answered, member:, status: :yes)
        answered.update!(status: :canceled)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "canceled")

        expect(response.body).to include "Spring concert", "you said yes"
      end

      it "puts no question on an ended event to a member asked for a response" do
        member = create(:member, :active)
        asked = confirmed_event(member, days: -9, name: "Spring concert")
        create(:registration, event: asked, member:, status: :response_requested)
        asked.update!(status: :canceled)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "canceled")

        expect(response.body).to include "Spring concert"
        expect(response.body).not_to include "Did you go?"
      end

      it "puts no question on an event still ahead to a member asked for a response" do
        member = create(:member, :active)
        asked = confirmed_event(member, days: 9, name: "Autumn gig")
        create(:registration, event: asked, member:, status: :response_requested)
        asked.update!(status: :canceled)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "canceled")

        expect(response.body).to include "Autumn gig"
        expect(response.body).not_to include "Are you coming?"
      end
    end

    # The gap the two scopes left between them, and what the hero does about it. The row examples
    # use an `unconfirmed` event so `Group#featured_event` cannot claim it for the card: what they
    # are about is `Event.current_and_upcoming` carrying it at all, and a hero that swallowed it would make
    # the delimited id assertion pass for the wrong reason.
    context "when an event is under way" do
      it "keeps it on the upcoming list" do
        member = create(:member, :active)
        running = running_event(member, status: :unconfirmed)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response.body).to include %(id="#{ActionView::RecordIdentifier.dom_id(running)}")
      end

      it "keeps it off the past list" do
        member = create(:member, :active)
        running = running_event(member, status: :unconfirmed)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "past")

        expect(response.body).not_to include %(id="#{ActionView::RecordIdentifier.dom_id(running)}")
      end

      # The screen's largest element used to name a later event than the one the reader was at.
      # Both halves in one example because they are one behaviour: the running event takes the card
      # and the later one is demoted to a row, and asserting either alone passes on a screen that
      # drew both as heroes or neither.
      it "gives the hero to the running event and leaves the later one a row" do
        freeze_time do
          member = create(:member, :active)
          running = running_event(member, status: :confirmed)
          later = confirmed_event(member, days: 1, name: "Sunday service")
          sign_in_as(member.user)

          get group_events_path(member.group)

          expect(response.body).to include "Happening now · ends in about 1 hour",
            %(id="#{ActionView::RecordIdentifier.dom_id(running, :next_up)}"), %(id="#{ActionView::RecordIdentifier.dom_id(later)}")
          expect(response.body).not_to include "Next up ·"
        end
      end
    end

    # The empty state, one sentence per list, asserted both ways round: the positive alone was
    # satisfied by a screen carrying both sentences, and the negative alone by a screen carrying
    # neither. Swapping the two literals reddens both examples, which is the mutation the pair
    # exists for.
    context "when the group has nothing on the list being requested" do
      it "says nothing is coming up on an empty upcoming list" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response.body).to include "Nothing coming up."
        expect(response.body).not_to include "No past events."
      end

      it "says there are no past events on an empty past list" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "past")

        expect(response.body).to include "No past events."
        expect(response.body).not_to include "Nothing coming up."
      end

      it "says there are no canceled events on an empty canceled list" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "canceled")

        expect(response.body).to include "No canceled events."
        expect(response.body).not_to include "Nothing coming up."
      end
    end

    # The other half of `open_to_answers?`'s status test. An unconfirmed event is on the list and is
    # still ahead, so it does put the question: nobody has called it off, and gauging who would come is most of
    # what an unconfirmed event is for. Without this the `unconfirmed?` term is a one-token deletion
    # nothing catches.
    context "when the group's only upcoming event is unconfirmed and the reader's response is requested" do
      it "puts the question under its row" do
        member = create(:member, :active)
        pencilled = create(:event, group: member.group, creator: member, status: :unconfirmed,
          name: "Extra rehearsal", starts_at: 2.days.from_now, ends_at: 2.days.from_now + 2.hours)
        create(:registration, event: pencilled, member:, status: :response_requested)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response.body).to include "Extra rehearsal", "Are you coming?"
      end
    end

    context "when the group's only upcoming event has been called off" do
      it "leaves it off the list and says nothing is coming up" do
        member = create(:member, :active)
        create(:event, :from_the_future, group: member.group, creator: member, status: :canceled, name: "Autumn gig")
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response.body).to include "Nothing coming up."
        expect(response.body).not_to include "Autumn gig"
      end
    end

    context "when the group's only upcoming event is unconfirmed" do
      # What a wrong filter looks like from the reader's side: an unconfirmed event is not a
      # commitment, so no card is drawn at all. A model spec cannot show this - `#featured_event`
      # answering the wrong record and the card being drawn anyway are the same thing there.
      it "draws no hero card" do
        freeze_time do
          owner = create(:member, :owner)
          create(:event, group: owner.group, creator: owner, status: :unconfirmed,
            starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour)
          sign_in_as(owner.user)

          get group_events_path(owner.group)

          expect(response.body).not_to include "Next up"
        end
      end
    end
  end

  describe "GET /groups/:group_id/events/:id" do
    # Frame 4c: a pushed screen's title stands in the header beside the back chevron, in the group name's place, and with the name go the switcher and the pencil that belong to it.
    it "titles the header Event, beside the back chevron, in the group name's place" do
      owner = create(:member, :active, :owner, group: create(:group, name: "Riverside Choir"))
      create(:member, user: owner.user, group: create(:group))
      event = create(:event, group: owner.group, creator: owner)
      sign_in_as(owner.user)

      get group_event_path(event.group, event)

      header = Nokogiri::HTML(response.body).at_css("header")
      expect([ header.at_css("h1")&.text, header.at_css("a[aria-label='Back']")&.[]("href"), header.text.include?("Riverside Choir") ]).to eq [ "Event", group_events_path(event.group), false ]
    end

    # The header's tabs stay on a form, out of its way from the breakpoint up, while the dock a phone pins to the bottom leaves it, so it never crowds the form's buttons or the keyboard.
    it "keeps the header's tabs on the edit form and leaves the dock off it" do
      owner = create(:member, :active, :owner)
      event = create(:event, group: owner.group, creator: owner)
      sign_in_as(owner.user)

      get edit_group_event_path(event.group, event)

      html = Nokogiri::HTML(response.body)
      expect([ html.css("header a[aria-label='Events']").size, html.css(".dock").size ]).to eq [ 1, 0 ]
    end

    # A screen pushed from the event goes back to it rather than to the events list: editing it, copying it and adding someone to it.
    it "takes the back chevron from editing the event back to the event" do
      owner = create(:member, :active, :owner)
      event = create(:event, group: owner.group, creator: owner)
      sign_in_as(owner.user)

      get edit_group_event_path(event.group, event)

      expect(Nokogiri::HTML(response.body).at_css("header a[aria-label='Back']")&.[]("href")).to eq group_event_path(event.group, event)
    end

    it "takes the back chevron from duplicating the event back to the event" do
      owner = create(:member, :active, :owner)
      event = create(:event, group: owner.group, creator: owner)
      sign_in_as(owner.user)

      get duplicate_group_event_path(event.group, event)

      expect(Nokogiri::HTML(response.body).at_css("header a[aria-label='Back']")&.[]("href")).to eq group_event_path(event.group, event)
    end

    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        get group_event_path(event.group, event)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        event = create(:event)
        sign_in_as(create(:user))

        get group_event_path(event.group, event)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the event page" do
        event = create(:event)
        sign_in_as(event.creator.user)

        get group_event_path(event.group, event)

        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as a paused member" do
      it "shows the event page" do
        event = create(:event)
        member = create(:member, :paused, group: event.group)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(response).to have_http_status :ok
      end

      # A paused owner keeps read and loses every write, so the roles they hold must not bring the
      # controls back: each is checked against a write rule, which the paused pre-check refuses first.
      it "draws the roster with nothing to press, whatever roles they hold" do
        member = create(:member, :paused, :owner)
        event = detailed_event(member)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to include "Ben Cole"
        expect(response.body).not_to include "Yes for Ben Cole"
        expect(response.body).not_to include "Request a response from Ben Cole", "Request the rest"
      end

      it "offers neither Duplicate nor Edit" do
        member = create(:member, :paused, :owner)
        event = detailed_event(member)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to include "Tuesday rehearsal"
        expect(response.body).not_to include %(aria-label="Duplicate"), %(aria-label="Edit")
      end

      # The day before `detailed_event`, since an event that has ended takes no `maybe`.
      it "draws no answer row for their own registration" do
        travel_to Time.zone.parse("2026-09-01 12:00") do
          member = create(:member, :paused)
          event = detailed_event(member, reader_status: :maybe)
          sign_in_as(member.user)

          get group_event_path(event.group, event)

          expect(page_text(response.body)).to include "Who’s coming"
          expect(page_text(response.body)).not_to include "Are you coming?"
        end
      end
    end

    context "when signed in as an inactive member" do
      it "returns 404, exactly like a non-member" do
        event = create(:event)
        member = create(:member, :inactive, group: event.group)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an owner" do
      it "draws the event's facts under the pushed title" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(headings(response.body)).to include "Event"
        expect(page_text(response.body)).to include "Tuesday rehearsal", "Confirmed rehearsal", "Wed 2 Sep · 19:00–21:00", "Community Hall"
        expect(page_text(response.body)).to include "Managed by Ben C. · Created by Alice B.", "Bring the new folders."
      end

      it "offers Duplicate and Edit in the title row" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(response.body).to include duplicate_group_event_path(event.group, event), %(aria-label="Duplicate")
        expect(response.body).to include edit_group_event_path(event.group, event), %(aria-label="Edit")
      end

      # The day before `detailed_event`, since an event that has ended offers no Maybe pill.
      it "draws the answer pills on every roster row" do
        travel_to Time.zone.parse("2026-09-01 12:00") do
          owner = create(:member, :active, :owner)
          event = detailed_event(owner)
          sign_in_as(owner.user)

          get group_event_path(event.group, event)

          expect(response.body).to include "Yes for Ben Cole", "Maybe for Carla Duke", "No for Alice Bird"
        end
      end

      # After the end the pills are Yes and No, so a maybe given before the event has no pill to light, and the status icon says where that row stands instead.
      it "offers yes and no on an ended event's roster, and a status icon on a row that said maybe" do
        owner = create(:member, :active, :owner)
        event = travel_to(Time.zone.parse("2026-09-01 12:00")) { detailed_event(owner, reader_status: :maybe) }
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(response.body).to include "Yes for Ben Cole", "No for Ben Cole", %(title="Maybe")
        expect(response.body).not_to include "Maybe for Ben Cole", "Maybe for #{owner.full_name}"
      end

      # `Registration` refuses every answer on an event that is over, so a pill there is a control
      # certain to fail. Taking somebody off stays, since correcting a closed roster is still theirs.
      it "leaves the pills off the roster of a concluded event, and keeps the status icons" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        event.update!(status: :concluded)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(response.body).to include "Place reserved, no response requested yet"
        expect(response.body).not_to include "Yes for Ben Cole"
        # With no pill lit to say where an answered row stands, the status icon says it instead.
        expect(response.body).to include %(title="Yes")
      end

      it "puts the reserved icon and a plain paper plane on a reserved row, and the tinted plane alone on a requested row" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        fragment = Nokogiri::HTML(response.body)
        ben, carla = [ "Ben Cole", "Carla Duke" ].map { fragment.at_xpath("//tr[td[text()='#{it}']]") }
        expect(ben.css("span[title]").map { it["title"] }).to eq [ "Place reserved, no response requested yet" ]
        expect(ben.at_css("button[aria-label^='Request a response from Ben Cole']")["class"]).to include "text-icon-muted"
        expect(carla.css("span[title]")).to be_empty
        expect(carla.at_css("button[aria-label='Response requested from Carla Duke']")["class"]).to include "text-info"
      end

      # The tally's colours: the chosen answer in its status colour, every control not yet used in the muted icon ink.
      it "colours the roster's pills as the Who’s coming? tally does" do
        travel_to Time.zone.parse("2026-09-01 12:00") do
          owner = create(:member, :active, :owner)
          event = detailed_event(owner)
          sign_in_as(owner.user)

          get group_event_path(event.group, event)

          classes = Nokogiri::HTML(response.body).then { |html| [ "Yes for Alice Bird", "Maybe for Alice Bird" ].map { html.at_css("button[aria-label='#{it}']")["class"] } }
          expect(classes).to match [ include("text-success"), include("text-icon-muted") ]
        end
      end

      it "draws the status icon rather than the paper plane on a paused member's held row" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        dan = create(:member, :active, group: owner.group, user: create(:user, :with_full_profile, first_name: "Dan", last_name: "Ellis"))
        create(:registration, event:, member: dan, status: :reserved)
        dan.update!(status: :paused)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to include "Dan Ellis"
        expect(response.body).to include "Request a response from Ben Cole"
        expect(response.body).not_to include "Request a response from Dan Ellis"
      end

      it "offers Request the rest while an active member's place is only held" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(response.body).to include "Request the rest", group_event_response_request_path(event.group, event)
      end

      it "offers Reserve a place for everyone while an active member is off the list" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        create(:member, :active, group: owner.group)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(response.body).to include "Reserve a place for everyone", group_event_reservation_path(event.group, event)
      end

      it "offers no Reserve a place for everyone once every active member is listed" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        owner.group.members.active.where.not(id: event.registrations.select(:member_id)).find_each { create(:registration, event:, member: it) }
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(response.body).not_to include "Reserve a place for everyone"
      end

      it "offers no Request the rest once every active member's response is requested" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        event.registrations.reserved.update_all(status: :response_requested)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(response.body).to include %(aria-label="Edit")
        expect(response.body).not_to include "Request the rest"
      end

      it "states the tally in one line under the rows, above the buttons, with the paused and inactive members on the list" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        create(:registration, event:, member: create(:member, :paused, group: owner.group))
        create(:member, :active, group: owner.group)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to match(/Carla Duke.*4 of 5 active members are on the list\. 1 paused member is on the list too\..*Reserve a place for everyone/)
      end
    end

    # `events.creator_id` carries no foreign key and `Member#created_events` no `dependent:`, so
    # removing the member who created an event leaves the event pointing at nobody.
    context "when the event's creator has been removed from the group" do
      it "draws the event with the manager alone on the credits line" do
        member = create(:member, :active)
        event = detailed_event(member)
        event.creator.destroy!
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to include "Managed by Ben C."
        expect(page_text(response.body)).not_to include "Created by"
      end
    end

    context "when signed in as a plain member" do
      # The owner's rows with every control gone: the order is `Event#roster`'s, asserted here only
      # as far as that this screen draws it, and a reserved row carries the bookmark because a
      # member's view has no paper plane to read the state from.
      it "draws the same rows in roster order as status icons, with nothing to press" do
        member = create(:member, :active)
        event = detailed_event(member)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to match(/Alice Bird.*Ben Cole.*Carla Duke/)
        expect(response.body).to include "Place reserved, no response requested yet", "Response requested"
        expect(response.body).not_to include "Yes for Ben Cole"
        expect(response.body).not_to include "Yes for #{member.full_name}", "Request a response from Ben Cole", "Request the rest", "Reserve a place for everyone"
      end

      it "draws the list by status when the reader last chose it, with the Response header marked sorted" do
        member = create(:member, :active)
        event = detailed_event(member)
        sign_in_as(member.user)
        cookies[:roster_order] = "status"

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to match(/Alice Bird.*Carla Duke.*Ben Cole/)
        expect(Nokogiri::HTML(response.body).css("th[aria-sort='ascending']").map { it.text.strip }).to eq [ "Response" ]
      end

      it "draws the list in reverse when the reader last chose descending, with the header marked so, and offers ascending on its next press" do
        member = create(:member, :active)
        event = detailed_event(member)
        sign_in_as(member.user)
        cookies[:roster_order] = "name"
        cookies[:roster_descending] = "true"

        get group_event_path(event.group, event)

        fragment = Nokogiri::HTML(response.body)
        expect(page_text(response.body)).to match(/Carla Duke.*Ben Cole.*Alice Bird/)
        expect(fragment.css("th[aria-sort='descending']").map { it.text.strip }).to eq [ "Name" ]
        expect(fragment.css("th[aria-sort] input[name='descending']").map { it["value"] }).to eq [ "false" ]
      end

      it "offers descending on the next press of the sorted header, and ascending on the other" do
        member = create(:member, :active)
        event = detailed_event(member)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(Nokogiri::HTML(response.body).css("th input[name='descending']").map { it["value"] }).to eq %w[ true false ]
      end

      it "draws the list by name for an order the list does not offer, with the Name header marked sorted" do
        member = create(:member, :active)
        event = detailed_event(member)
        sign_in_as(member.user)
        cookies[:roster_order] = "created_at"

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to match(/Alice Bird.*Ben Cole.*Carla Duke/)
        expect(Nokogiri::HTML(response.body).css("th[aria-sort='ascending']").map { it.text.strip }).to eq [ "Name" ]
      end

      # `detailed_event` has ended, so a place held for the reader is now a question about whether they went.
      it "puts whether they went to a held place, with yes and no only" do
        member = create(:member, :active)
        event = detailed_event(member, reader_status: :reserved)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to include "Did you go?"
        expect(response.body).to include %(name="registration[status]" value="yes"), %(name="registration[status]" value="no")
        expect(response.body).not_to include %(name="registration[status]" value="maybe")
      end

      it "keeps a yes given before the event as the answer, with no maybe beside it" do
        member = create(:member, :active)
        event = detailed_event(member)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to include "Did you go?"
        expect(response.body).not_to include %(name="registration[status]" value="maybe")
      end

      # `Registration` refuses every answer on a concluded event, so its screen puts no question.
      it "puts no question on an event somebody has concluded" do
        member = create(:member, :active)
        event = detailed_event(member, reader_status: :response_requested)
        event.update!(status: :concluded)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to include "Tuesday rehearsal"
        expect(page_text(response.body)).not_to include "Did you go?"
      end

      it "offers neither Duplicate nor Edit" do
        member = create(:member, :active)
        event = detailed_event(member)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to include "Tuesday rehearsal"
        expect(response.body).not_to include %(aria-label="Duplicate"), %(aria-label="Edit")
      end

      # The reader's own answer stands on the page above the card that holds the counts and the roster they unfold.
      # The day before `detailed_event`, since an event that has ended takes no `maybe`.
      it "draws the answer row above the roster's card, outside it" do
        travel_to Time.zone.parse("2026-09-01 12:00") do
          member = create(:member, :active)
          event = detailed_event(member, reader_status: :maybe)
          sign_in_as(member.user)

          get group_event_path(event.group, event)

          expect(page_text(response.body)).to match(/Are you coming\?.*Who’s coming.*active members are on the list/)
          expect(Nokogiri::HTML(response.body).css(".card").map(&:text).join).not_to include "Are you coming?"
        end
      end

      it "opens the roster when the hero card's responses link here" do
        travel_to Time.zone.parse("2026-09-01 12:00") do
          member = create(:member, :active)
          event = detailed_event(member, reader_status: :response_requested)
          sign_in_as(member.user)

          get group_event_path(event.group, event, responses: "show")

          expect(Nokogiri::HTML(response.body).at_css("details.collapse")["open"]).not_to be_nil
        end
      end

      # The tags alone, on the same row as the heading that says what they count.
      it "draws the tally's tags right after the Who’s coming heading" do
        travel_to Time.zone.parse("2026-09-01 12:00") do
          member = create(:member, :active)
          event = detailed_event(member, reader_status: :response_requested)
          sign_in_as(member.user)

          get group_event_path(event.group, event)

          row = Nokogiri::HTML(response.body).at_css("details.collapse summary").element_children
          expect([ row[0].text.squish, row[1].at_css("[aria-label='yes']") ]).to match [ "Who’s coming?", be_present ]
        end
      end

      it "draws the five count tags and the reader's own question" do
        travel_to Time.zone.parse("2026-09-01 12:00") do
          member = create(:member, :active)
          event = detailed_event(member, reader_status: :response_requested)
          sign_in_as(member.user)

          get group_event_path(event.group, event)

          expect(response.body).to include %(aria-label="yes"), %(aria-label="maybe"), %(aria-label="no"), %(aria-label="no reply"), %(aria-label="reserved")
          expect(page_text(response.body)).to include "Are you coming?"
        end
      end
    end

    # The manager's column of the events table: editing their event and filling it, and nothing the
    # three roles keep for themselves - copying it, deleting it, overruling an answer, taking
    # somebody off the list.
    context "when signed in as the event's manager" do
      it "offers Edit, and nothing the roles keep for themselves" do
        manager = create(:member, :active)
        event = detailed_event(manager)
        event.update!(manager:)
        sign_in_as(manager.user)

        get group_event_path(event.group, event)

        expect(response.body).to include %(aria-label="Edit")
        expect(response.body).not_to include %(aria-label="Duplicate"), "Yes for Ben Cole"
      end

      it "offers the paper plane and Request the rest, because filling the event is the manager's job" do
        manager = create(:member, :active)
        event = detailed_event(manager)
        event.update!(manager:)
        create(:member, :active, group: manager.group)
        sign_in_as(manager.user)

        get group_event_path(event.group, event)

        expect(response.body).to include "Request a response from Ben Cole", "Request the rest"
      end
    end

    # The two other columns the events table marks wherever it marks the owner, and the one role
    # column it leaves blank on every write row.
    context "when signed in as an administrator" do
      it "offers Duplicate and Edit" do
        actor = create(:member, :active, :administrator)
        event = detailed_event(actor)
        sign_in_as(actor.user)

        get group_event_path(event.group, event)

        expect(response.body).to include %(aria-label="Duplicate"), %(aria-label="Edit")
      end
    end

    context "when signed in as an events administrator" do
      it "offers Duplicate and Edit" do
        actor = create(:member, :active, :events_administrator)
        event = detailed_event(actor)
        sign_in_as(actor.user)

        get group_event_path(event.group, event)

        expect(response.body).to include %(aria-label="Duplicate"), %(aria-label="Edit")
      end

      it "draws the answer pills on another member's row" do
        actor = create(:member, :active, :events_administrator)
        event = detailed_event(actor)
        sign_in_as(actor.user)

        get group_event_path(event.group, event)

        expect(response.body).to include "Yes for Ben Cole"
      end

      # The day before `detailed_event`, since an event that has ended takes no `maybe`.
      it "draws the answer row for their own registration" do
        travel_to Time.zone.parse("2026-09-01 12:00") do
          actor = create(:member, :active, :events_administrator)
          event = detailed_event(actor, reader_status: :maybe)
          sign_in_as(actor.user)

          get group_event_path(event.group, event)

          expect(page_text(response.body)).to include "Are you coming?"
        end
      end
    end

    context "when signed in as a members administrator" do
      it "offers nothing that changes the event or its roster" do
        actor = create(:member, :active, :members_administrator)
        event = detailed_event(actor)
        sign_in_as(actor.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to include "Tuesday rehearsal"
        expect(response.body).not_to include %(aria-label="Duplicate"), %(aria-label="Edit")
        expect(response.body).not_to include "Yes for Ben Cole"
      end
    end
  end

  describe "GET /groups/:group_id/events/new" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get new_group_event_path(create(:group))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        sign_in_as(create(:user))

        get new_group_event_path(create(:group))

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an events administrator" do
      it "shows the new event page" do
        member = create(:member, :active, :events_administrator)
        sign_in_as(member.user)

        get new_group_event_path(member.group)

        expect(response).to have_http_status :ok
      end

      it "picks reserving a place for everyone" do
        actor = create(:member, :active, :events_administrator)
        sign_in_as(actor.user)

        get new_group_event_path(actor.group)

        expect(Nokogiri::HTML(response.body).at_css("input[name='event[list_filling]'][checked]")["value"]).to eq "reserve"
      end

      # Frame 4e's names for the fields, which the locale gives the error messages too.
      it "names the fields the way the frames do, with the zone the times are typed in" do
        member = create(:member, :active, :events_administrator)
        sign_in_as(member.user)

        get new_group_event_path(member.group)

        expect(response.body).to include ">Starts</label>", ">Ends</label>", ">Notes</label>", "Typed and shown in Europe/Zagreb"
        expect(response.body).to include %(aria-label="Unconfirmed"), %(aria-label="Gig"), "New address…", "Create event</button>"
      end
    end

    context "when signed in as a member who cannot create events" do
      it "refuses the form rather than offering one the submission would reject" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get new_group_event_path(member.group)

        expect(response).to redirect_to root_path
      end
    end
  end

  describe "GET /groups/:group_id/events/:id/duplicate" do
    # `duplicate` renders the `new` form, and `new` resolves new? through create?, so a rule that
    # let a paused member through here contradicted the one guarding the other door onto it.
    context "when signed in as a paused member" do
      it "refuses, exactly as new does" do
        event = create(:event)
        actor = create(:member, :paused, group: event.group)
        sign_in_as(actor.user)

        get duplicate_group_event_path(event.group, event)

        expect(response).to redirect_to root_path
      end
    end

    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        get duplicate_group_event_path(event.group, event)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        event = create(:event)
        sign_in_as(create(:user))

        get duplicate_group_event_path(event.group, event)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as the event's manager" do
      it "cannot duplicate the event, which is creating one" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)

        get duplicate_group_event_path(event.group, event)

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as an events administrator" do
      it "says which event it copied and what the copy changed" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group, starts_at: Time.zone.local(2026, 9, 2, 19), ends_at: Time.zone.local(2026, 9, 2, 21))
        sign_in_as(actor.user)

        get duplicate_group_event_path(event.group, event)

        expect(response.body).to include "Duplicate event", "Copied from Wed 2 Sep. Dates moved on 7 days, status back to unconfirmed, nobody registered yet."
        expect(response.body).to include %(value="2026-09-09T19:00:00"), "Create copy</button>"
        expect(Nokogiri::HTML(response.body).at_css("input[name=original_id]")["value"]).to eq event.id.to_s
      end

      # `dup` copies the `address_id` but not the loaded address, so the form reading it on the copy was a lazy load the strict loading refuses.
      it "copies an event that has an address, with the address" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group, address: create(:address, name: "KBBL Broadcasting"))
        sign_in_as(actor.user)

        get duplicate_group_event_path(event.group, event)

        expect(response).to have_http_status :ok
        expect(response.body).to include "KBBL Broadcasting"
      end

      # The app's alert kinds and nothing custom: the copy's note is an info alert, announced politely since it describes the form rather than reporting a failure.
      it "picks reserving a place for everyone, since the copy is a new event" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        get duplicate_group_event_path(event.group, event)

        expect(Nokogiri::HTML(response.body).at_css("input[name='event[list_filling]'][checked]")["value"]).to eq "reserve"
      end

      it "states what the copy changed in an info alert" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        get duplicate_group_event_path(event.group, event)

        expect(Nokogiri::HTML(response.body).at_css("[role=status].alert-info")&.text).to include "Copied from"
      end

      # `Event#duplicate` is `dup`, so the copy carries the original's `creator_id`. Nothing submits
      # it, which is what makes the duplicate belong to whoever saves it rather than to whoever made
      # the original.
      it "carries no creator into the form" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        get duplicate_group_event_path(event.group, event)

        expect(response.body).not_to include "event[creator_id]"
      end
    end
  end

  describe "GET /groups/:group_id/events/:id/edit" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        get edit_group_event_path(event.group, event)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        event = create(:event)
        sign_in_as(create(:user))

        get edit_group_event_path(event.group, event)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an events administrator" do
      it "shows the edit event page" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(response).to have_http_status :ok
      end

      it "leads the form's button row with Delete, opening the plain confirm sheet" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        trigger = Nokogiri::HTML(response.body).at_css("form[action='#{group_event_path(event.group, event)}'] .btn:first-child[type='submit']")
        expect([ trigger["form"], trigger.text.strip ]).to eq [ "#{ActionView::RecordIdentifier.dom_id(event, :confirm_delete)}_form", "Delete event" ]
        expect(response.body).to include "Delete this event?", "Keep event"
        expect(response.body).not_to include "to confirm"
      end

      # The trash, the cross and the check, read off each icon's own drawing, since the legend names the meaning and the file names the glyph.
      it "draws an icon in every button of the form's row" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        row = Nokogiri::HTML(response.body).at_css("form[action='#{group_event_path(event.group, event)}'] .btn[form]").parent
        drawing = ->(name) { File.read(Rails.root.join("app/assets/svg/icons/heroicons/mini/#{name}.svg"))[/ d="([^"]+)"/, 1] }
        expect(row.css(".btn").map { [ it.text.strip, it.at_css("svg.size-icon-control path")["d"] ] }).to eq [
          [ "Delete event", drawing.("trash") ], [ "Cancel", drawing.("x-mark") ], [ "Save changes", drawing.("check") ]
        ]
      end

      # `Group#addresses` offers the group's home address beside the events' own, and correcting it
      # is the owner's alone, so the row is offered for use but not for correction.
      it "offers Correct it on an event's address and not on the group's home address" do
        home  = create(:address, name: "Rehearsal Hall")
        actor = create(:member, :active, :events_administrator, group: create(:group, address: home))
        venue = create(:address, name: "Studio B")
        event = create(:event, group: actor.group, address: venue)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(response.body).to include "Rehearsal Hall", edit_address_path(venue)
        expect(response.body).not_to include edit_address_path(home)
      end

      # The saved address drawn into the new-address fields would be built afresh by every plain
      # Save, so the fields are drawn empty and the saved address is picked instead.
      it "picks the saved address and leaves the new-address fields empty" do
        actor = create(:member, :active, :events_administrator)
        venue = create(:address, name: "Studio B")
        event = create(:event, group: actor.group, address: venue)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(response.body).to include %(value="#{venue.id}" checked="checked")
        expect(response.body).not_to include %(value="Studio B")
      end
    end

    context "when signed in as an events administrator, editing who is on the list" do
      it "puts a trash on each member on the list and a + on each active member off it" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        listed = create(:registration, event:, member: create(:member, :active, group: event.group)).member
        missing = create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        fragment = Nokogiri::HTML(response.body)
        expect(fragment.at_css("input[name='removing_ids[]'][value='#{listed.id}']")["disabled"]).to be_nil
        expect(fragment.at_css("input[name='adding_ids[]'][value='#{missing.id}']")).to be_present
      end

      it "folds who is on the list shut on the edit page" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(Nokogiri::HTML(response.body).at_css("#event_list details")["open"]).to be_nil
      end

      it "puts a disabled add on a paused member off the list" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        paused = create(:member, :paused, group: event.group)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(Nokogiri::HTML(response.body).at_css("input[name='adding_ids[]'][value='#{paused.id}']")["disabled"]).to eq "disabled"
      end

      # A paused or inactive member's registration has no other way off the list.
      it "puts a trash on a paused and an inactive member's registration, and lists no inactive member off the list" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        paused = create(:registration, event:, member: create(:member, :paused, group: event.group)).member
        gone = create(:registration, event:, member: create(:member, :inactive, group: event.group)).member
        unlisted = create(:member, :inactive, group: event.group)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(Nokogiri::HTML(response.body).css("input[name='removing_ids[]']").map { it["value"] }).to contain_exactly paused.id.to_s, gone.id.to_s
        expect(page_text(response.body)).not_to include unlisted.full_name
      end

      it "badges a member on the list who is not active with their status, beside the name, and an active one with nothing" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        listed = [ :active, :paused, :inactive ].map { create(:registration, event:, member: create(:member, it, group: event.group)).member }
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        badges = listed.map { |member| Nokogiri::HTML(response.body).xpath("//div[span[normalize-space()='#{member.full_name}']]/span[contains(@class, 'badge')]").map(&:text) }
        expect(badges).to eq [ [], [ "paused" ], [ "inactive" ] ]
      end
    end

    context "when signed in as the event's manager" do
      it "shows the edit event page, holding no role at all" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(response).to have_http_status :ok
      end

      it "offers no Delete, which is not the manager's to do" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(response.body).to include "Save changes</button>"
        expect(response.body).not_to include "Delete event"
      end

      it "puts the trash on a member on the list disabled, because removing is not the manager's" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        listed = create(:registration, event:, member: create(:member, :active, group: event.group)).member
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(Nokogiri::HTML(response.body).at_css("input[name='removing_ids[]'][value='#{listed.id}']")["disabled"]).to eq "disabled"
      end

      # The order the fields are filled in is a decision of the owner's, and only the markup's order says it.
      it "draws who is on the list after the dates, and Where between the manager and the description" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        fields = %w[ event_ends_at event_list event_manager_id event_address_id_ event_description ]
        expect(fields.map { response.body.index(%(id="#{it}")) }).to eq fields.map { response.body.index(%(id="#{it}")) }.sort
      end
    end

    context "when signed in as an administrator" do
      it "ends with Delete" do
        actor = create(:member, :active, :administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(response.body).to include "Delete this event?"
      end
    end

    # Opening the form is a write rule, so a paused member is refused a form whose Save they could
    # not use, whatever roles they hold.
    context "when signed in as a paused events administrator" do
      it "refuses the form" do
        actor = create(:member, :paused, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(response).to redirect_to root_path
      end
    end

    # Creating an event is a record of who made it and confers nothing afterwards: the role that
    # allowed it may be gone tomorrow while the column stays.
    context "when signed in as the event's creator, holding no role" do
      it "refuses the form" do
        event = create(:event)
        sign_in_as(event.creator.user)

        get edit_group_event_path(event.group, event)

        expect(response).to redirect_to root_path
      end
    end
  end

  describe "POST /groups/:group_id/events" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        group = create(:group)

        post group_events_path(group), params: { event: { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and does not create the event" do
        group  = create(:group)
        params = { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour }
        sign_in_as(create(:user))

        expect { post group_events_path(group), params: { event: params } }
          .not_to change(Event, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an events administrator" do
      # The creator assertion belongs here rather than only in the model spec: the default reads
      # `Current.member`, which needs both the session resumed and `GroupScoped` having assigned
      # `Current.group`, and only a real request proves the two happen before the create runs. A
      # reordering that left either unset would pass every model spec.
      it "creates the event with the signed-in member as its creator" do
        creator = create(:member, :active, :events_administrator)
        sign_in_as(creator.user)
        params  = { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour }

        expect { post group_events_path(creator.group), params: { event: params } }.to change(Event, :count).by(1)
        expect(response).to redirect_to group_event_path(creator.group, Event.sole)
        expect(Event.sole.creator).to eq creator
      end

      it "re-renders the new page with the address fields when the event is invalid" do
        member = create(:member, :active, :events_administrator)
        sign_in_as(member.user)

        expect { post group_events_path(member.group), params: { event: { name: "" } } }
          .not_to change(Event, :count)

        expect(response).to have_http_status :unprocessable_content
        expect(response.body).to include "event_address_attributes_name"
      end

      it "keeps a typed address in the re-rendered new page when the event is invalid" do
        member = create(:member, :active, :events_administrator)
        sign_in_as(member.user)

        post group_events_path(member.group), params: { event: { name: "", address_attributes: { name: "Rehearsal room" } } }

        expect(response).to have_http_status :unprocessable_content
        expect(response.body).to include %(value="Rehearsal room")
      end

      it "keeps every typed value, and the message under the field it is about" do
        member = create(:member, :active, :events_administrator)
        sign_in_as(member.user)
        params = { name: "", status: "confirmed", category: "gig", description: "Bring the scores", manager_id: member.id,
                   starts_at: "2026-10-01T19:00", ends_at: "2026-10-01T21:00" }

        post group_events_path(member.group), params: { event: params }

        fragment = Nokogiri::HTML(response.body)
        expect(fragment.at_css("p#event_name_error").text).to eq "Name can't be blank"
        expect(fragment.css("input[type=radio][checked]").map { it["value"] }).to include "confirmed", "gig"
        expect(fragment.at_css("textarea#event_description").text.strip).to eq "Bring the scores"
        expect(fragment.at_css("select#event_manager_id option[selected]")["value"]).to eq member.id.to_s
      end

      it "re-renders the new event screen when a new event is refused" do
        member = create(:member, :active, :events_administrator)
        sign_in_as(member.user)

        post group_events_path(member.group), params: { event: { name: "" } }

        fragment = Nokogiri::HTML(response.body)
        expect(headings(response.body)).to include "New event"
        expect(response.body).to include "Create event</button>"
        expect(fragment.at_xpath("//a[normalize-space()='Cancel']")["href"]).to eq group_events_path(member.group)
        expect(page_text(response.body)).not_to include "Copied from"
      end

      it "re-renders the duplicate screen when a copy is refused" do
        member   = create(:member, :active, :events_administrator)
        original = create(:event, group: member.group, starts_at: Time.zone.local(2026, 9, 2, 19), ends_at: Time.zone.local(2026, 9, 2, 21))
        sign_in_as(member.user)

        post group_events_path(member.group), params: { original_id: original.id, event: { name: "" } }

        fragment = Nokogiri::HTML(response.body)
        expect(headings(response.body)).to include "Duplicate event"
        expect(page_text(response.body)).to include "Copied from Wed 2 Sep."
        expect(response.body).to include "Create copy</button>"
        expect(fragment.at_xpath("//a[normalize-space()='Cancel']")["href"]).to eq group_event_path(member.group, original)
      end

      it "keeps every typed value of a refused copy, the message under its field and the summary" do
        member   = create(:member, :active, :events_administrator)
        original = create(:event, group: member.group)
        sign_in_as(member.user)

        post group_events_path(member.group), params: { original_id: original.id, event: { name: "", description: "Bring the scores" } }

        fragment = Nokogiri::HTML(response.body)
        expect(fragment.at_css("textarea#event_description").text.strip).to eq "Bring the scores"
        expect(fragment.at_css("p#event_name_error").text).to eq "Name can't be blank"
        expect(fragment.at_css("#error_explanation[role=alert]")).to be_present
      end

      it "carries the original again, so a second refused copy is still the duplicate screen" do
        member   = create(:member, :active, :events_administrator)
        original = create(:event, group: member.group)
        sign_in_as(member.user)

        post group_events_path(member.group), params: { original_id: original.id, event: { name: "" } }

        expect(Nokogiri::HTML(response.body).at_css("input[name=original_id]")["value"]).to eq original.id.to_s
      end

      it "re-renders the new event screen for an original that belongs to another group" do
        member  = create(:member, :active, :events_administrator)
        foreign = create(:event, starts_at: Time.zone.local(2026, 8, 19, 19), ends_at: Time.zone.local(2026, 8, 19, 21))
        sign_in_as(member.user)

        post group_events_path(member.group), params: { original_id: foreign.id, event: { name: "" } }

        expect(headings(response.body)).to include "New event"
        expect(page_text(response.body)).not_to include "Copied from", "Wed 19 Aug"
      end

      it "creates no event for a member who manages one but holds no role" do
        actor = create(:member, :active)
        create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)
        params = { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour }

        expect { post group_events_path(actor.group), params: { event: params } }
          .not_to change(Event, :count)

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as an events administrator filling the list" do
      it "reserves a place for every active member, requests nothing, and leaves out a paused one" do
        creator = create(:member, :active, :events_administrator)
        active = create(:member, :active, group: creator.group)
        create(:member, :paused, group: creator.group)
        sign_in_as(creator.user)
        params = { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour, list_filling: "reserve" }

        post group_events_path(creator.group), params: { event: params }

        expect(Event.sole.registrations.reserved.pluck(:member_id)).to contain_exactly(creator.id, active.id)
      end

      it "requests a response from every active member, and leaves out a paused one" do
        creator = create(:member, :active, :events_administrator)
        active = create(:member, :active, group: creator.group)
        create(:member, :paused, group: creator.group)
        sign_in_as(creator.user)
        params = { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour, list_filling: "request" }

        post group_events_path(creator.group), params: { event: params }

        expect(Event.sole.registrations.response_requested.pluck(:member_id)).to contain_exactly(creator.id, active.id)
      end

      it "fills nothing when Not now stays picked" do
        creator = create(:member, :active, :events_administrator)
        sign_in_as(creator.user)
        params = { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour, list_filling: "" }

        post group_events_path(creator.group), params: { event: params }

        expect(Event.sole.registrations).to be_empty
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and does not create the event" do
        member = create(:member, :paused)
        params = { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour }
        sign_in_as(member.user)

        expect { post group_events_path(member.group), params: { event: params } }
          .not_to change(Event, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /groups/:group_id/events/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        patch group_event_path(event.group, event), params: { event: { name: "Renamed" } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and leaves the event unchanged" do
        event = create(:event, name: "Original")
        sign_in_as(create(:user))

        patch group_event_path(event.group, event), params: { event: { name: "Renamed" } }

        expect(response).to have_http_status :not_found
        expect(event.reload.name).to eq "Original"
      end
    end

    context "when signed in as an events administrator" do
      it "updates the event" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { name: "Renamed" } }

        expect(response).to redirect_to group_event_path(event.group, event)
        expect(event.reload.name).to eq "Renamed"
      end

      it "re-renders the edit page with the address fields when the event is invalid" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { name: "" } }

        expect(response).to have_http_status :unprocessable_content
        expect(response.body).to include "event_address_attributes_name"
      end

      it "keeps the event's address on the re-rendered edit page when the event is invalid" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group, address: create(:address))
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { name: "" } }

        expect(response).to have_http_status :unprocessable_content
        expect(response.body).to include edit_address_path(event.address)
      end

      it "reserves a place for each member added and removes each member taken off, saving the event with them" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        leaving = create(:registration, event:, member: create(:member, :active, group: event.group))
        arriving = create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { name: "Renamed" }, adding_ids: [ arriving.id ], removing_ids: [ leaving.member_id ] }

        expect(response).to redirect_to group_event_path(event.group, event)
        expect(event.reload.name).to eq "Renamed"
        expect(event.registrations.pluck(:member_id, :status)).to contain_exactly [ arriving.id, "reserved" ]
      end

      it "changes nobody on the list when the event is invalid, and keeps the member added marked" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        arriving = create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        expect { patch group_event_path(event.group, event), params: { event: { name: "" }, adding_ids: [ arriving.id ] } }
          .not_to change(Registration, :count)
        expect(response).to have_http_status :unprocessable_content
        expect(Nokogiri::HTML(response.body).at_css("input[name='adding_ids[]'][value='#{arriving.id}']")["checked"]).to eq "checked"
      end

      it "draws who is on the list open when a refused save keeps rows marked" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        arriving = create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { name: "" }, adding_ids: [ arriving.id ] }

        expect(Nokogiri::HTML(response.body).at_css("#event_list details")["open"]).to eq "open"
      end

      it "ignores a posted group_id, leaving the event in its own group" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        other_group = create(:group)
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { group_id: other_group.id } }

        expect(event.reload.group).to eq actor.group
      end
    end

    context "when signed in as an events administrator, with a list that moved or a forged post" do
      it "leaves another event's registration alone, whatever is posted for removal" do
        event = create(:event)
        elsewhere = create(:registration, event: create(:event, group: event.group), member: create(:member, :active, group: event.group))
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)

        patch group_event_path(event.group, event), params: { event: { name: "Renamed" }, removing_ids: [ elsewhere.member_id ] }

        expect(Registration.exists?(elsewhere.id)).to be true
      end

      # One member a post, so each guard in `arriving_members` is what refuses its own case.
      it "refuses the save, adding nobody, when a member marked to add is paused, inactive, already on the list or from another group" do
        event = create(:event, name: "Original")
        registered = create(:registration, event:, member: create(:member, :active, group: event.group)).member
        unoffered = [ create(:member, :paused, group: event.group), create(:member, :inactive, group: event.group), registered, create(:member, :active) ]
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)

        statuses = unoffered.map { |member| patch(group_event_path(event.group, event), params: { event: { name: "Renamed" }, adding_ids: [ member.id ] }) }

        expect(statuses).to all eq 422
        expect([ Registration.count, event.reload.name ]).to eq [ 1, "Original" ]
      end

      it "draws the form again after that refusal, with the typed values and the other marks kept and the paused member's add disabled" do
        event = create(:event, name: "Original")
        arriving, paused = create_list(:member, 2, :active, group: event.group)
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)
        paused.update!(status: :paused)

        patch group_event_path(event.group, event), params: { event: { name: "Renamed" }, adding_ids: [ arriving.id, paused.id ] }

        form = Nokogiri::HTML(response.body)
        expect([ flash[:alert], form.at_css("input[name='event[name]']")["value"] ]).to eq [ EventsController::MOVED_ON, "Renamed" ]
        expect([ arriving, paused ].map { |member| form.at_css("input[name='adding_ids[]'][value='#{member.id}']").to_h.slice("checked", "disabled") }).to eq [ { "checked" => "checked" }, { "disabled" => "disabled" } ]
      end

      # The row the intersection cannot see: it lands after `arriving_members` has read the set and reaches the unique index instead. The racing row rolls back with the rest here, where a real one on another connection would not, so what this proves is the answer rather than the row count.
      it "draws the form again, saving nothing, when somebody is added to the list mid-request" do
        event = create(:event, name: "Original")
        available = create(:member, :active, group: event.group)
        sign_in_as(create(:member, :active, :events_administrator, group: event.group).user)

        racing_on(event) do
          patch group_event_path(event.group, event), params: { event: { name: "Renamed" }, adding_ids: [ available.id ] }
        end

        expect(response).to have_http_status :unprocessable_content
        expect(flash[:alert]).to include "somebody changed the list"
        expect(event.reload.name).to eq "Original"
      end
    end

    context "when signed in as the event's manager editing who is on the list" do
      it "checks the registering row before reserving" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        arriving = create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        expect { patch group_event_path(event.group, event), params: { event: { name: "Renamed" }, adding_ids: [ arriving.id ] } }
          .to be_authorized_to(:create?, have_attributes(event_id: event.id)).with(RegistrationPolicy)
      end

      # The rule is checked against the event as it was loaded, so handing it on in the same save
      # does not take the manager's own reserving away from them.
      it "still reserves when the same save hands the event to somebody else" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        successor = create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { manager_id: successor.id }, adding_ids: [ successor.id ] }

        expect(event.reload.manager).to eq successor
        expect(event.registrations.reserved.pluck(:member_id)).to eq [ successor.id ]
      end

      # The form drawn again after a refused save asks the same question the save did, of the event as it was loaded, so the manager's marks survive a hand-on typed in the same go.
      it "keeps the member added marked when a save that hands the event on is refused" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        successor = create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { name: "", manager_id: successor.id }, adding_ids: [ successor.id ] }

        expect(response).to have_http_status :unprocessable_content
        expect(Nokogiri::HTML(response.body).at_css("input[name='adding_ids[]'][value='#{successor.id}']")&.[]("checked")).to eq "checked"
      end

      it "refuses a removal and saves nothing, because removing is not the manager's" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor, name: "Original")
        listed = create(:registration, event:, member: create(:member, :active, group: event.group))
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { name: "Renamed" }, removing_ids: [ listed.member_id ] }

        expect(response).to redirect_to root_path
        expect(listed.reload).to be_persisted
        expect(event.reload.name).to eq "Original"
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and leaves the event unchanged" do
        event = create(:event, name: "Original")
        member = create(:member, :paused, group: event.group)
        sign_in_as(member.user)

        patch group_event_path(event.group, event), params: { event: { name: "Renamed" } }

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
        expect(event.reload.name).to eq "Original"
      end
    end
  end

  describe "DELETE /groups/:group_id/events/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        event = create(:event)

        expect { delete group_event_path(event.group, event) }
          .not_to change(Event, :count)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and does not destroy the event" do
        event = create(:event)
        sign_in_as(create(:user))

        expect { delete group_event_path(event.group, event) }
          .not_to change(Event, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an events administrator" do
      it "destroys the event" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        expect { delete group_event_path(event.group, event) }
          .to change(Event, :count).by(-1)

        expect(response).to redirect_to group_events_path(event.group)
      end
    end

    context "when signed in as the event's manager" do
      it "refuses, because filling an event is the manager's job and deleting one is not" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)

        expect { delete group_event_path(event.group, event) }
          .not_to change(Event, :count)

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and does not destroy the event" do
        event = create(:event)
        member = create(:member, :paused, group: event.group)
        sign_in_as(member.user)

        expect { delete group_event_path(event.group, event) }
          .not_to change(Event, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "foreign keys posted in the body" do
    # Pointing an event at another group's address is what makes it an owner of that address - and
    # so lets it be edited - by somebody with no claim on it. The picker is scoped; the parameter
    # was not.
    it "ignores an address_id belonging to another group" do
      event = create(:event, address: create(:address))
      actor = create(:member, :active, group: event.group)
      elsewhere = create(:address, name: "Someone Else's Venue")
      create(:group, address: elsewhere)
      sign_in_as(actor.user)

      patch group_event_path(event.group, event), params: { event: { address_id: elsewhere.id } }

      expect(event.reload.address).not_to eq elsewhere
    end

    # A member of the event's own group, holding the role that carries the update through, and a
    # name posted alongside so the update is one that lands: the new name proves the request was
    # processed and the unchanged creator proves the parameter is gone rather than guarded. An
    # outsider's id would prove neither, since the guard that used to drop it and the parameter's
    # absence are indistinguishable from out there.
    it "ignores a creator_id, even one from the event's own group" do
      actor = create(:member, :active, :events_administrator)
      event = create(:event, group: actor.group)
      sign_in_as(actor.user)

      patch group_event_path(event.group, event), params: { event: { name: "Renamed", creator_id: actor.id } }

      expect(event.reload.name).to eq "Renamed"
      expect(event.creator).not_to eq actor
    end

    # The second door onto an address, and the one the policy cannot see. `address_attributes` with
    # an `:id` would have `accepts_nested_attributes_for` update that address in place with only
    # `EventPolicy#update?` checked, so an events_administrator edited the group's home address that
    # `AddressPolicy` reserves to the `owner`. With no `:id` permitted the attributes build a new
    # address and the event is repointed at it, which is this actor's own to do - what they cannot
    # do is reach the address they named. Both halves are asserted: an untouched home address alone
    # would pass just as well if the whole update had failed, and the new name proves it did not.
    it "builds a new address rather than editing the one address_attributes names" do
      home  = create(:address, name: "Rehearsal Hall")
      group = create(:group, address: home)
      event = create(:event, group:, address: home)
      actor = create(:member, :active, :events_administrator, group:)
      sign_in_as(actor.user)

      patch group_event_path(group, event),
        params: { event: { name: "Renamed", address_attributes: { id: home.id, name: "Hijacked" } } }

      expect(event.reload.name).to eq "Renamed"
      expect(home.reload.name).to eq "Rehearsal Hall"
      expect(event.address.name).to eq "Hijacked"
    end

    # The form draws the new-address fields whichever row is picked, so a reader who typed into
    # them and then picked a saved address posts both. The pick is what they chose last.
    it "uses a picked address and builds nothing from new-address fields posted beside it" do
      actor = create(:member, :active, :events_administrator)
      event = create(:event, group: actor.group)
      venue = create(:address, name: "Studio B")
      create(:event, group: actor.group, address: venue)
      sign_in_as(actor.user)

      expect {
        patch group_event_path(event.group, event), params: { event: { address_id: venue.id, address_attributes: { name: "Typed first" } } }
      }.not_to change(Address, :count)

      expect(event.reload.address).to eq venue
    end

    it "builds the new address when the New address row is picked" do
      actor = create(:member, :active, :events_administrator)
      event = create(:event, group: actor.group, address: create(:address, name: "Studio B"))
      sign_in_as(actor.user)

      patch group_event_path(event.group, event), params: { event: { address_id: "", address_attributes: { name: "Village Hall" } } }

      expect(event.reload.address.name).to eq "Village Hall"
    end
  end

  describe "an inactive member's event list" do
    it "does not include the former group's events" do
      event = create(:event, name: "Rehearsal")
      actor = create(:member, :inactive, group: event.group)
      sign_in_as(actor.user)

      get group_events_path(event.group)

      expect(response).to have_http_status :not_found
    end
  end

  # Runs the block with the row the request is about to write already landing from inside the request, after `arriving_members` has read the set, which is the only place a spec can reach that window. The lambda is held in a local so `skip_callback` is handed the object `set_callback` was given.
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

  # The screen the frames draw: a named creator and manager, a place, notes, and a roster of three
  # named members in three states, so every row an example reads has a name to find it by. The
  # reader is registered too, with `reader_status:`, and the date is fixed because the schedule
  # line is copy the examples read.
  def detailed_event(reader, reader_status: :yes)
    group = reader.group
    alice = create(:member, :active, group:, user: create(:user, :with_full_profile, first_name: "Alice", last_name: "Bird"))
    ben = create(:member, :active, group:, user: create(:user, :with_full_profile, first_name: "Ben", last_name: "Cole"))
    carla = create(:member, :active, group:, user: create(:user, :with_full_profile, first_name: "Carla", last_name: "Duke"))
    event = create(:event,
      group:,
      creator: alice,
      manager: ben,
      name: "Tuesday rehearsal",
      category: :rehearsal,
      status: :confirmed,
      description: "Bring the new folders.",
      address: create(:address, name: "Community Hall"),
      starts_at: Time.zone.parse("2026-09-02 19:00"),
      ends_at: Time.zone.parse("2026-09-02 21:00"))
    create(:registration, event:, member: alice, status: :yes)
    create(:registration, event:, member: ben, status: :reserved)
    create(:registration, event:, member: carla, status: :response_requested)
    create(:registration, event:, member: reader, status: reader_status)
    event
  end

  # An event the reader is in the middle of: started, not yet ended. `status:` is the caller's,
  # because whether `Group#featured_event` may claim it for the hero is exactly what the examples
  # around it differ on.
  def running_event(member, status:)
    create(:event, group: member.group, creator: member, status: status,
      starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
  end

  # The card states its own copy, so the examples above need an event with a fixed name, place and
  # offset rather than the factory's random ones. `status:` is named because the base factory
  # leaves it at the model default, `unconfirmed`, which `Group#featured_event` deliberately excludes.
  #
  # The offset is exact, never an hour of its own day. The kicker rounds the distance to the
  # nearest day, so an event pinned to 19:00 is "in 2 days" or "in 3 days" depending on the hour
  # the suite starts at, and `freeze_time` cannot help: it stops the clock rather than setting it.
  def confirmed_event(member, days:, name: "Autumn concert", category: :other)
    create(:event,
      group: member.group,
      creator: member,
      name: name,
      category: category,
      status: :confirmed,
      address: create(:address, name: "Community Hall"),
      starts_at: days.days.from_now,
      ends_at: days.days.from_now + 2.hours)
  end
end
