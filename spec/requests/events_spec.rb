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

      # The select is the screen's title as well as its filter, so what proves the title is there
      # is the control's own two options rather than a heading above them.
      it "titles the screen with the select that chooses between the two lists" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response.body).to include %(name="scope"), ">Upcoming events</option>", ">Past events</option>"
        expect(response.body).to include %(<option selected="selected" value="upcoming">)
      end

      # The accessible name carries a warning that choosing navigates, which is what the plan's
      # `## Settled` accepts SC 3.2.2 on. Asserted here because axe-core has no rule for that
      # criterion, so `be_accessible` passes over a name shortened back to the bare purpose. What
      # this pins is the wording; that the control still changes context on input, nothing can.
      it "warns in the select's accessible name that choosing navigates" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response.body).to include %(aria-label="Which events to show; choosing one loads that list")
      end

      # Who may create an event is `EventPolicy#create?`, and a refused reader gets no control
      # rather than a disabled one - so the assertion is the route's absence, not a class.
      it "offers the New button to a reader who may create events" do
        owner = create(:member, :owner)
        sign_in_as(owner.user)

        get group_events_path(owner.group)

        expect(response.body).to include %(href="#{new_group_event_path(owner.group)}")
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

    # Times are frozen because the card states the distance to the event in words, so "in 2 days"
    # would otherwise depend on how long the suite takes to reach this file. What the freeze does
    # not do is decide which hour it stops at, which is `confirmed_event`'s job below.
    context "when the group has a next event" do
      # The hero card, one row beneath it and the reader's own answer row: the three pieces the
      # event card partials draw, asserted here rather than in a view spec because what a reader
      # sees on this screen is the response's own text.
      it "draws the hero card, a row beneath it and the question for an invited owner" do
        freeze_time do
          owner = create(:member, :owner)
          next_up = confirmed_event(owner, name: "Tuesday rehearsal", category: :rehearsal, days: 2)
          later = confirmed_event(owner, name: "Sunday service", days: 5)
          create(:registration, event: next_up, member: owner, status: :invited)
          sign_in_as(owner.user)

          get group_events_path(owner.group)

          expect(response.body).to include "Next up · in 2 days", "Tuesday rehearsal", "Confirmed rehearsal", "Are you coming?"
          expect(response.body).to include ActionView::RecordIdentifier.dom_id(later)
        end
      end

      it "draws the answer, the counts and the names for a plain member who has answered" do
        freeze_time do
          member = create(:member, :active, user: create(:user, :with_full_profile, first_name: "Carla", last_name: "Dean"))
          next_up = confirmed_event(member, days: 2)
          create(:registration, event: next_up, member:, status: :yes)
          sign_in_as(member.user)

          get group_events_path(member.group)

          expect(response.body).to include "Your answer:", "no reply", "Carla Dean said yes"
          expect(response.body).not_to include "Are you coming?"
        end
      end

      # Where the question is asked, which is the one thing about it this screen decides: inside the
      # hero's own card, and again under any row the reader was invited to. `id="events"` is the
      # list's wrapper, so a match that crosses it has one copy on each side of the list's start.
      #
      # The count is what makes the order mean anything. Either copy alone satisfies the match on
      # its own, which is what the screen looked like when the answer row sat once below the list.
      it "asks inside the hero card and again under an invited row" do
        owner = create(:member, :owner)
        next_up = confirmed_event(owner, days: 2, name: "Tuesday rehearsal")
        later = confirmed_event(owner, days: 5, name: "Sunday service")
        create(:registration, event: next_up, member: owner, status: :invited)
        create(:registration, event: later, member: owner, status: :invited)
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
        asked_row = confirmed_event(member, days: 7)
        create(:registration, event: answered_row, member:, status: :maybe)
        create(:registration, event: asked_row, member:, status: :invited)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response.body).to include "your answer: maybe"
        expect(response.body).not_to include "your answer: invited"
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
        expect(response.body).to match %r{btn-primary[^>]*>\s*Maybe\s*</button>}
      end

      it "leaves the pills out for a paused member, who may not write an answer" do
        freeze_time do
          member = create(:member, :paused)
          next_up = confirmed_event(member, days: 2)
          registration = create(:registration, event: next_up, member:, status: :invited)
          sign_in_as(member.user)

          get group_events_path(member.group)

          expect(response.body).to include "Next up · in 2 days"
          expect(response.body).not_to include "Are you coming?"
          expect(response.body).not_to include %(action="#{group_event_registration_path(member.group, next_up, registration)}")
        end
      end

      # Both halves of the nobody-asked state in one example, because they are one behaviour: the
      # tags are absent and a sentence stands where they were. The negative alone was satisfied by
      # a card that drew nothing there at all, which is what this state used to look like.
      it "says nobody has been asked while every registration is still reserved" do
        freeze_time do
          owner = create(:member, :owner)
          next_up = confirmed_event(owner, days: 2)
          create(:registration, event: next_up, member: owner, status: :reserved)
          sign_in_as(owner.user)

          get group_events_path(owner.group)

          expect(response.body).to include "Next up · in 2 days", "Nobody asked yet · 1 on the list"
          expect(response.body).not_to include "no reply"
        end
      end

      it "offers Invite everyone while every registration is still reserved" do
        freeze_time do
          owner = create(:member, :owner)
          next_up = confirmed_event(owner, days: 2)
          create(:registration, event: next_up, member: owner, status: :reserved)
          sign_in_as(owner.user)

          get group_events_path(owner.group)

          expect(response.body).to include "Invite everyone", group_event_invitation_path(owner.group, next_up)
        end
      end

      it "offers no Invite everyone once somebody has been asked" do
        freeze_time do
          owner = create(:member, :owner)
          next_up = confirmed_event(owner, days: 2)
          create(:registration, event: next_up, member: owner, status: :invited)
          create(:registration, event: next_up, member: create(:member, group: owner.group), status: :reserved)
          sign_in_as(owner.user)

          get group_events_path(owner.group)

          expect(response.body).to include "Next up · in 2 days"
          expect(response.body).not_to include "Invite everyone"
        end
      end

      # "Every registration is reserved" holds of an empty list, which has nobody to ask.
      it "offers no Invite everyone while nobody is on the list" do
        freeze_time do
          owner = create(:member, :owner)
          confirmed_event(owner, days: 2)
          sign_in_as(owner.user)

          get group_events_path(owner.group)

          expect(response.body).to include "Next up · in 2 days"
          expect(response.body).not_to include "Invite everyone"
        end
      end

      it "offers a plain member no Invite everyone" do
        freeze_time do
          member = create(:member, :active)
          next_up = confirmed_event(member, days: 2)
          create(:registration, event: next_up, member:, status: :reserved)
          sign_in_as(member.user)

          get group_events_path(member.group)

          expect(response.body).to include "Nobody asked yet · 1 on the list"
          expect(response.body).not_to include "Invite everyone"
        end
      end
    end

    # A negative offset is what makes an event past: `confirmed_event` reads `days:` as a distance
    # from now in either direction, and an event that started nine days ago ended eight days and
    # twenty-two hours ago, which is what `Event.past` asks about.
    context "when the past list is asked for" do
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
      # is asked here too - in the tense the event is in. Both halves in one example: the past
      # tense present and the present tense absent, since a screen asking neither would satisfy
      # either assertion alone.
      it "asks in the past tense under an event that has ended" do
        member = create(:member, :active)
        over = confirmed_event(member, days: -9, name: "Spring concert")
        create(:registration, event: over, member:, status: :invited)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "past")

        expect(response.body).to include "Spring concert", "Did you go?"
        expect(response.body).not_to include "Are you coming?"
      end

      it "does not ask at all under an event somebody has concluded" do
        member = create(:member, :active)
        over = create(:event, group: member.group, creator: member, status: :concluded,
          name: "Summer gig", starts_at: 9.days.ago, ends_at: 9.days.ago + 2.hours)
        create(:registration, event: over, member:, status: :invited)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "past")

        expect(response.body).to include "Summer gig"
        expect(response.body).not_to include "Did you go?", "Are you coming?"
      end

      # The select states which list is open, so a reader who lands on the past one by a typed URL
      # sees the control agreeing with what is under it.
      it "shows the past option as the select's own value" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "past")

        expect(response.body).to include %(<option selected="selected" value="past">)
      end

      # Anything that is not "past" is the upcoming list, which is what keeps a mistyped URL a
      # screen rather than an error.
      it "reads an unknown scope as the upcoming list" do
        member = create(:member, :active)
        confirmed_event(member, days: -2, name: "Summer gig")
        sign_in_as(member.user)

        get group_events_path(member.group, scope: "sideways")

        expect(response.body).not_to include "Summer gig"
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
    context "when the group has nothing on the list being asked for" do
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
    end

    # The other half of `open_to_answers?`'s status test. An unconfirmed event is on the list and is
    # still ahead, so it does ask: nobody has called it off, and gauging who would come is most of
    # what an unconfirmed event is for. Without this the `unconfirmed?` term is a one-token deletion
    # nothing catches.
    context "when the group's only upcoming event is unconfirmed and the reader was invited" do
      it "asks under its row" do
        member = create(:member, :active)
        pencilled = create(:event, group: member.group, creator: member, status: :unconfirmed,
          name: "Extra rehearsal", starts_at: 2.days.from_now, ends_at: 2.days.from_now + 2.hours)
        create(:registration, event: pencilled, member:, status: :invited)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response.body).to include "Extra rehearsal", "Are you coming?"
      end
    end

    # `Event.current_and_upcoming` filters on `ends_at` alone, so a canceled event still ahead is on
    # the list. It draws, and it does not ask: the clock has not ruled it out but its status has.
    context "when the group's only upcoming event has been called off" do
      it "draws the row and does not ask under it" do
        member = create(:member, :active)
        called_off = create(:event, group: member.group, creator: member, status: :canceled,
          name: "Autumn gig", starts_at: 2.days.from_now, ends_at: 2.days.from_now + 2.hours)
        create(:registration, event: called_off, member:, status: :invited)
        sign_in_as(member.user)

        get group_events_path(member.group)

        expect(response.body).to include "Autumn gig"
        expect(response.body).not_to include "Are you coming?"
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
      # controls back: each is asked of a write rule, which the paused pre-check refuses first.
      it "draws the roster with nothing to press, whatever roles they hold" do
        member = create(:member, :paused, :owner)
        event = detailed_event(member)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to include "Ben Cole"
        expect(response.body).not_to include "Take Ben Cole off the list", "Yes for Ben Cole", "Add someone", "Delete event"
        expect(response.body).not_to include "Invite Ben Cole", "Invite the rest"
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

      it "offers Duplicate and Edit in the title row and Delete at the bottom" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(response.body).to include duplicate_group_event_path(event.group, event), %(aria-label="Duplicate")
        expect(response.body).to include edit_group_event_path(event.group, event), %(aria-label="Edit")
        expect(page_text(response.body)).to include "Delete event"
      end

      it "draws the answer pills and a take-off on every roster row, and Add someone" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(response.body).to include "Yes for Ben Cole", "Maybe for Carla Duke", "No for Alice Bird"
        expect(response.body).to include "Take Ben Cole off the list", "Take Carla Duke off the list"
        expect(response.body).to include new_group_event_registration_path(event.group, event)
      end

      # `Registration` refuses every answer on an event that is over, so a pill there is a control
      # certain to fail. Taking somebody off stays, since correcting a closed roster is still theirs.
      it "leaves the pills off the roster of a concluded event, and keeps the badges and the take-off" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        event.update!(status: :concluded)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(response.body).to include "Place reserved, not asked yet", "Take Ben Cole off the list"
        expect(response.body).not_to include "Yes for Ben Cole"
        # With no pill lit to say where an answered row stands, the badge says it instead.
        expect(response.body).to include %(title="Yes")
      end

      it "puts a plain paper plane on a reserved row and the tinted one on an invited row" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        fragment = Nokogiri::HTML(response.body)
        expect(fragment.at_css("button[aria-label='Invite Ben Cole']")["class"]).not_to include "text-primary"
        expect(fragment.at_css("button[aria-label='Carla Duke is invited, no reply yet']")["class"]).to include "text-primary"
      end

      it "draws the badge rather than the paper plane on a paused member's held row" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        dan = create(:member, :active, group: owner.group, user: create(:user, :with_full_profile, first_name: "Dan", last_name: "Ellis"))
        create(:registration, event:, member: dan, status: :reserved)
        dan.update!(status: :paused)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to include "Dan Ellis"
        expect(response.body).to include "Invite Ben Cole"
        expect(response.body).not_to include "Invite Dan Ellis"
      end

      it "offers Invite the rest while an active member's place is only held" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(response.body).to include "Invite the rest", group_event_invitation_path(event.group, event)
      end

      it "offers no Invite the rest once every active member is asked" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        event.registrations.reserved.update_all(status: :invited)
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(response.body).to include "Add someone"
        expect(response.body).not_to include "Invite the rest"
      end

      it "names a paused member with no registration as left out above the rows" do
        owner = create(:member, :active, :owner)
        event = detailed_event(owner)
        create(:member, :paused, group: owner.group, user: create(:user, :with_full_profile, first_name: "Dan", last_name: "Ellis"))
        sign_in_as(owner.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to match(/Dan Ellis is paused, left out.*Alice Bird/)
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
      it "draws the same rows in roster order as badges, with nothing to press" do
        member = create(:member, :active)
        event = detailed_event(member)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to match(/Alice Bird.*Carla Duke.*Ben Cole/)
        expect(response.body).to include "Place reserved, not asked yet", "Invited, no reply yet"
        expect(response.body).not_to include "Take Ben Cole off the list", "Yes for Ben Cole", "Add someone"
        expect(response.body).not_to include "Yes for #{member.full_name}", "Invite Ben Cole", "Invite the rest"
      end

      it "offers no Duplicate, Edit or Delete" do
        member = create(:member, :active)
        event = detailed_event(member)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to include "Tuesday rehearsal"
        expect(response.body).not_to include %(aria-label="Duplicate"), %(aria-label="Edit"), "Delete event"
      end

      # The frames' order, which the markup has to carry because the disclosure cannot: its summary
      # is the counts, and the roster it unfolds is drawn after the answer row rather than inside it.
      it "draws the answer row between the counts and the roster" do
        member = create(:member, :active)
        event = detailed_event(member, reader_status: :maybe)
        sign_in_as(member.user)

        get group_event_path(event.group, event)

        expect(page_text(response.body)).to match(/Who’s coming.*Your answer:.*Who’s invited/)
      end

      it "draws the four count tags and the reader's own question" do
        travel_to Time.zone.parse("2026-09-01 12:00") do
          member = create(:member, :active)
          event = detailed_event(member, reader_status: :invited)
          sign_in_as(member.user)

          get group_event_path(event.group, event)

          expect(response.body).to include %(aria-label="yes"), %(aria-label="maybe"), %(aria-label="no"), %(aria-label="no reply")
          expect(page_text(response.body)).to include "Are you coming?"
        end
      end
    end

    # The manager's column of the events table: editing their event and filling it, and nothing the
    # three roles keep for themselves - copying it, deleting it, overruling an answer, taking
    # somebody off the list.
    context "when signed in as the event's manager" do
      it "offers Edit and Add someone, and nothing the roles keep for themselves" do
        manager = create(:member, :active)
        event = detailed_event(manager)
        event.update!(manager:)
        sign_in_as(manager.user)

        get group_event_path(event.group, event)

        expect(response.body).to include %(aria-label="Edit"), new_group_event_registration_path(event.group, event)
        expect(response.body).not_to include %(aria-label="Duplicate"), "Delete event", "Yes for Ben Cole", "Take Ben Cole off the list"
      end

      it "offers the paper plane and Invite the rest, because filling the event is the manager's job" do
        manager = create(:member, :active)
        event = detailed_event(manager)
        event.update!(manager:)
        create(:member, :active, group: manager.group)
        sign_in_as(manager.user)

        get group_event_path(event.group, event)

        expect(response.body).to include "Invite Ben Cole", "Invite the rest"
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

      # Frame 4e's names for the fields, which the locale gives the error messages too.
      it "names the fields the way the frames do, with the zone the times are typed in" do
        member = create(:member, :active, :events_administrator)
        sign_in_as(member.user)

        get new_group_event_path(member.group)

        expect(response.body).to include ">Starts</label>", ">Ends</label>", ">Notes</label>", "Typed and shown in Europe/Zagreb"
        expect(response.body).to include %(aria-label="Unconfirmed"), %(aria-label="Gig"), "New address…", %(value="Create event")
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
        expect(response.body).to include %(value="2026-09-09T19:00:00"), %(value="Create copy")
        expect(Nokogiri::HTML(response.body).at_css("input[name=original_id]")["value"]).to eq event.id.to_s
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

      it "ends with Delete, opening the plain confirm sheet" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(response.body).to include "Delete this event?", "Keep event"
        expect(response.body).not_to include "to confirm"
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

        expect(response.body).to include %(value="Save changes")
        expect(response.body).not_to include "Delete event"
      end

      it "offers Invite all active members, because inviting is the manager's too" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(response.body).to include "Invite all active members"
      end
    end

    # A paused member keeps the read that opens the form and loses the write the box would make.
    context "when signed in as a paused events administrator" do
      it "shows the form without Invite all active members" do
        actor = create(:member, :paused, :events_administrator)
        event = create(:event, group: actor.group)
        sign_in_as(actor.user)

        get edit_group_event_path(event.group, event)

        expect(response.body).to include %(value="Save changes")
        expect(response.body).not_to include "Invite all active members"
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
        expect(response.body).to include %(value="Create event")
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
        expect(response.body).to include %(value="Create copy")
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

    context "when signed in as an events administrator ticking Invite all active members" do
      it "invites every active member and leaves out a paused one" do
        creator = create(:member, :active, :events_administrator)
        active = create(:member, :active, group: creator.group)
        create(:member, :paused, group: creator.group)
        sign_in_as(creator.user)
        params = { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour, invite_active_members: "1" }

        post group_events_path(creator.group), params: { event: params }

        expect(Event.sole.registrations.invited.pluck(:member_id)).to contain_exactly(creator.id, active.id)
      end

      it "invites nobody when the box is left unticked" do
        creator = create(:member, :active, :events_administrator)
        sign_in_as(creator.user)
        params = { name: "Rehearsal", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour, invite_active_members: "0" }

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

      it "ignores a posted group_id, leaving the event in its own group" do
        actor = create(:member, :active, :events_administrator)
        event = create(:event, group: actor.group)
        other_group = create(:group)
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { group_id: other_group.id } }

        expect(event.reload.group).to eq actor.group
      end
    end

    context "when signed in as the event's manager ticking Invite all active members" do
      it "invites the members still missing and touches no existing registration" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor, status: :confirmed)
        answered = create(:registration, event:, member: actor, status: :no)
        missing = create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { invite_active_members: "1" } }

        expect(answered.reload).to be_no
        expect(event.registrations.invited.pluck(:member_id)).to contain_exactly(event.creator_id, missing.id)
      end

      # The attribute casts "true", "on" and "yes" as it casts "1", so the gate has to read the box
      # the same way or a differently spelled tick invites without the invitation row being asked.
      it "asks the invitation row however the tick is spelled" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        sign_in_as(actor.user)

        expect { patch group_event_path(event.group, event), params: { event: { invite_active_members: "true" } } }
          .to be_authorized_to(:create?, have_attributes(event_id: event.id)).with(RegistrationPolicy)
      end

      # The invitation is asked of the event as it was loaded, so handing it on in the same save
      # does not take the manager's own invitation away from them.
      it "still invites when the same save hands the event to somebody else" do
        actor = create(:member, :active)
        event = create(:event, group: actor.group, manager: actor)
        successor = create(:member, :active, group: event.group)
        sign_in_as(actor.user)

        patch group_event_path(event.group, event), params: { event: { manager_id: successor.id, invite_active_members: "1" } }

        expect(event.reload.manager).to eq successor
        expect(event.registrations.invited.count).to eq 3
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
    # `EventPolicy#update?` asked, so an events_administrator edited the group's home address that
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
    create(:registration, event:, member: carla, status: :invited)
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
