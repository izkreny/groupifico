require 'rails_helper'

RSpec.describe "Groups", type: :request do
  describe "GET /groups" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get groups_path

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows the groups page" do
        sign_in_as(create(:user))

        get groups_path

        expect(response).to have_http_status :ok
      end

      it "lists only the groups the acting user belongs to" do
        member = create(:member)
        other_group = create(:group) # the acting user does not belong to this one
        sign_in_as(member.user)

        get groups_path

        expect(response.body).to include(ActionView::RecordIdentifier.dom_id(member.group))
        expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(other_group))
      end
    end

    # What a card says about the reader's standing and about the group. Which reader sees what is
    # this layer's question throughout, per the duplication rule in `.agents/testing.md`;
    # `spec/system/groups_index_spec.rb` only asserts that the cards paint and lead anywhere.
    describe "a group's card" do
      it "tags the reader who owns the group" do
        member = create(:member, :owner)
        sign_in_as(member.user)

        get groups_path

        expect(response.body).to include ">owner<"
      end

      it "tags the reader whose membership is paused" do
        member = create(:member, :paused)
        sign_in_as(member.user)

        get groups_path

        expect(response.body).to include ">paused<"
      end

      # Owner and paused are separate facts, and a group with a second active owner lets the first
      # pause and hold both - `Member#group_keeps_an_active_owner` permits it. Neither example above
      # reaches the combination, and an `if`/`elsif` passes both of them while telling such a reader
      # only that they own the group.
      it "tags a paused owner with both" do
        group = create(:group)
        # Not what permits the paused owner below - the record is inserted paused, past a guard
        # declared `on: :update` - but what makes the state one a real group can be in.
        create(:member, :owner, group:)
        member = create(:member, :paused, :owner, group:)
        sign_in_as(member.user)

        get groups_path

        expect(response.body).to include ">owner<"
        expect(response.body).to include ">paused<"
      end

      # An administrator administers members, which is a capability rather than a standing, and the
      # card says what the reader is. Watched failing against a tag drawn from `can_manage?`.
      it "tags an administrator with neither" do
        member = create(:member, :administrator)
        sign_in_as(member.user)

        get groups_path

        expect(response.body).not_to include ">owner<"
        expect(response.body).not_to include ">paused<"
      end

      # The reader is named as the event's creator deliberately: the event factory's `creator` is a
      # member of the same group, so letting it build its own would add a third person to a count
      # this example is about.
      it "counts the group's people and names the day it next meets" do
        freeze_time do
          member = create(:member, group: create(:group))
          create(:member, group: member.group)
          create(:member, :inactive, group: member.group) # has left, so is not one of the people
          create(:event, group: member.group, creator: member, status: :confirmed,
            starts_at: 2.days.from_now, ends_at: 2.days.from_now + 2.hours)
          sign_in_as(member.user)

          get groups_path

          expect(response.body).to include "2 members · next: #{2.days.from_now.strftime('%a %-d %b')}"
        end
      end

      it "says nothing is scheduled for a group with no upcoming event" do
        member = create(:member)
        sign_in_as(member.user)

        get groups_path

        expect(response.body).to include "1 member · nothing scheduled"
      end
    end
  end

  describe "GET /groups/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get group_path(create(:group))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        sign_in_as(create(:user))

        get group_path(create(:group))

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an active member" do
      it "shows the group page" do
        member = create(:member, :active)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response).to have_http_status :ok
      end
    end

    context "when signed in as a paused member" do
      it "shows the group page" do
        member = create(:member, :paused)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response).to have_http_status :ok
      end

      it "reads successfully and writes unsuccessfully for the same member" do
        member = create(:member, :paused, group: create(:group, name: "Original"))
        sign_in_as(member.user)

        get group_path(member.group)
        expect(response).to have_http_status :ok

        patch group_path(member.group), params: { group: { name: "Renamed" } }
        expect(response).to redirect_to root_path
        expect(member.group.reload.name).to eq "Original"
      end
    end

    context "when signed in as an inactive member" do
      it "returns 404, exactly like a non-member" do
        member = create(:member, :inactive)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response).to have_http_status :not_found
      end
    end

    # The home's two states, and which controls each offers whom. `spec/system/group_home_spec.rb`
    # asserts that they paint and that "See all events" lands; none of that comes back here.
    describe "the group home" do
      it "leads with the next event and a way into the whole list" do
        member = create(:member, group: create(:group))
        event = create(:event, group: member.group, name: "Tuesday rehearsal", status: :confirmed,
          starts_at: 2.days.from_now, ends_at: 2.days.from_now + 2.hours)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response.body).to include "Tuesday rehearsal"
        expect(response.body).to include "Next up"
        expect(response.body).to include group_events_path(member.group)
      end

      # The answer row is `events/_rsvp`'s, and which of its states it draws is
      # `spec/requests/events_spec.rb`'s question. What belongs here is that this screen hands the
      # partial the reader's own registration at all: without `@membership`, `registration_for`
      # gets nil and an invited reader is never asked.
      it "asks the reader for their own answer" do
        member = create(:member, group: create(:group))
        event = create(:event, group: member.group, creator: member, status: :confirmed,
          starts_at: 2.days.from_now, ends_at: 2.days.from_now + 2.hours)
        create(:registration, event:, member:, status: :invited)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response.body).to include "Are you coming?"
      end

      it "shows the first-run screen to an owner whose group has no events" do
        member = create(:member, :owner)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response.body).to include "Nothing in the diary"
        expect(response.body).to include "Add your first rehearsal"
        expect(response.body).to include new_group_event_path(member.group)
      end

      # `EventPolicy#create?` is `can_manage?(:events)`, which a plain member does not hold, so the
      # call to action is absent rather than disabled - the epic's rule for every refused control.
      # The heading stays: an empty diary is a fact about the group, not a permission.
      it "offers a plain member the empty heading and nothing to press" do
        member = create(:member)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response.body).to include "Nothing in the diary"
        expect(response.body).not_to include "Add your first rehearsal"
        expect(response.body).not_to include new_group_event_path(member.group)
      end

      it "tells the group's only member that nobody else is there yet" do
        member = create(:member, :owner)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response.body).to include "just you in here so far"
      end

      it "says nothing of the kind once a second person has joined" do
        member = create(:member, :owner)
        create(:member, group: member.group)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response.body).not_to include "just you in here so far"
      end

      it "has lost the scaffold's heading and its button row" do
        member = create(:member, :owner)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response.body).not_to include "Showing group"
        expect(response.body).not_to include "Destroy this group"
        expect(response.body).not_to include "Back to groups"
      end
    end

    # Which of the shell's controls a given reader is offered. This is the layer that answers it,
    # per the duplication rule in `.agents/testing.md`: `spec/system/group_shell_spec.rb` asserts
    # that the chrome paints and that its controls behave, and never which reader sees what.
    #
    # Asserted on the `aria-label`, which is each control's accessible name and the only stable
    # thing about an icon-only button: there is no text to match and the SVG path is the wrong
    # thing to couple to.
    describe "the shell's controls" do
      it "offers the pencil to an owner" do
        member = create(:member, :owner)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response.body).to include 'aria-label="Edit group"'
      end

      # `GroupPolicy#edit?` is the owner's alone - an administrator is refused all three group
      # writes, which is the split `can_manage?` cannot express - so the control is absent rather
      # than disabled, per #235's second acceptance criterion.
      it "offers no pencil to an administrator, who may not edit the group" do
        member = create(:member, :administrator)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response.body).not_to include 'aria-label="Edit group"'
      end

      it "offers the switcher chevron to a reader with a second group" do
        member = create(:member)
        create(:member, user: member.user, group: create(:group))
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response.body).to include 'aria-label="Switch group"'
      end

      it "offers no switcher chevron to a reader with one group" do
        member = create(:member)
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response.body).not_to include 'aria-label="Switch group"'
      end

      # `menu-active` colours the reader's current group and says nothing to a screen reader, so
      # the row carries `aria-current` too. Asserted because an accessibility semantic nothing
      # reads is one nothing keeps.
      #
      # The assertion names the row rather than counting the attribute: presence and a count of one
      # are both invariant under marking the wrong group, which is the one mutation the attribute
      # exists to prevent. Watched failing with the comparison inverted, which marked "Harbour
      # Band" as current while the reader was in "Riverside Choir".
      it "marks the reader's current group in the switcher" do
        member = create(:member, group: create(:group, name: "Riverside Choir"))
        create(:member, user: member.user, group: create(:group, name: "Harbour Band"))
        sign_in_as(member.user)

        get group_path(member.group)

        marked = Nokogiri::HTML(response.body).css(%(a[aria-current="true"]))
        expect(marked.map { it[:href] }).to eq [ group_path(member.group) ]
      end

      # A group they have left is not a group they can switch to, so it must not raise the count
      # that decides whether the chevron appears either. Same leak `user.current_groups` closes for
      # the index, asked of the shell instead.
      it "offers no switcher chevron for a group the reader has left" do
        member = create(:member)
        create(:member, :inactive, user: member.user, group: create(:group))
        sign_in_as(member.user)

        get group_path(member.group)

        expect(response.body).not_to include 'aria-label="Switch group"'
      end
    end
  end

  # A failed `update` re-renders `edit` on the persisted record with the rejected attributes still
  # assigned, so the header and the screen's own heading would otherwise read a name the save
  # refused. Watched failing in both directions, one assertion each: against `name` in the layout
  # the header row loses the name, and against `name` in `groups/edit` no heading carries it.
  describe "the shell's header and the screen's heading after a refused rename" do
    it "keeps the stored group name in both" do
      member = create(:member, :owner, group: create(:group, name: "Riverside Choir"))
      sign_in_as(member.user)

      patch group_path(member.group), params: { group: { name: "" } }

      expect(response).to have_http_status :unprocessable_content
      expect(header_text(response.body)).to include "Riverside Choir"
      expect(headings(response.body)).to include "Riverside Choir"
    end
  end

  describe "GET /groups/new" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get new_group_path

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "shows the new group page" do
        sign_in_as(create(:user))

        get new_group_path

        expect(response).to have_http_status :ok
      end
    end
  end

  describe "GET /groups/:id/edit" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        get edit_group_path(create(:group))

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404" do
        sign_in_as(create(:user))

        get edit_group_path(create(:group))

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an owner" do
      it "shows the edit group page" do
        member = create(:member, :active, :owner)
        sign_in_as(member.user)

        get edit_group_path(member.group)

        expect(response).to have_http_status :ok
      end

      # Opening the form is a read, so the status pre-check lets a paused owner through and stops
      # them at the submission instead. `edit?` therefore answers `membership.owner?` under its own
      # name rather than through an alias or a `check?`, both of which rename the running rule to
      # `update?` and refuse this.
      it "shows the edit group page to a paused owner, who is stopped at the submission" do
        member = create(:member, :paused, :owner)
        sign_in_as(member.user)

        get edit_group_path(member.group)

        expect(response).to have_http_status :ok
      end

      # The confirm sheet's trigger is the delete form's own submit button, which is what makes the
      # sheet an enhancement rather than the only route: with JavaScript off the click posts the
      # delete straight away. The markup carries that claim, so it is asserted here rather than in
      # `spec/system/confirm_sheet_spec.rb` - `.rspec` keeps the system suite out of the runner's
      # own run, and this is the one gate a CI job sees.
      it "renders the delete as the trigger's own form" do
        member = create(:member, :owner)
        sign_in_as(member.user)

        get edit_group_path(member.group)

        body = Nokogiri::HTML(response.body)
        form = "form##{ActionView::RecordIdentifier.dom_id(member.group, :confirm_delete)}_form"
        expect(body.at_css("#{form}[action='#{group_path(member.group)}'][method='post']")).to be_present
        expect(body.at_css("#{form} input[name='_method'][value='delete']")).to be_present
        expect(body.at_css("#{form} button[type='submit']").text.strip).to eq "Delete group"
      end
    end

    context "when signed in as a member who does not own the group" do
      it "refuses an administrator with a redirect rather than a 404" do
        member = create(:member, :active, :administrator)
        sign_in_as(member.user)

        get edit_group_path(member.group)

        expect(response).to redirect_to root_path
      end
    end
  end

  describe "POST /groups" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        post groups_path, params: { group: { name: "Choraliers" } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when successfully signed in" do
      it "creates the group" do
        sign_in_as(create(:user))

        expect { post groups_path, params: { group: { name: "Choraliers" } } }
          .to change(Group, :count).by(1)

        expect(response).to redirect_to group_path(Group.sole)
      end

      it "creates a Member joining the acting user to the group with the owner role" do
        user = create(:user)
        sign_in_as(user)

        expect { post groups_path, params: { group: { name: "Choraliers" } } }
          .to change(Member, :count).by(1)

        member = Member.sole
        expect(member.user).to eq user
        expect(member.group).to eq Group.sole
        expect(member.roles.map(&:name)).to eq [ "owner" ]
      end

      it "lands the creator on the group page instead of a 404" do
        sign_in_as(create(:user))

        post groups_path, params: { group: { name: "Choraliers" } }
        follow_redirect!

        expect(response).to have_http_status :ok
      end

      it "responds :unprocessable_content and creates no records when the group is invalid" do
        sign_in_as(create(:user))

        group_count  = Group.count
        member_count = Member.count

        post groups_path, params: { group: { name: "" } }

        expect(Group.count).to eq group_count
        expect(Member.count).to eq member_count
        expect(response).to have_http_status :unprocessable_content
      end

      # `group_type` has no control on the group form - it is set from the hostname - so a per-field
      # error pattern has nowhere to put its message and the summary is the only thing that can
      # carry it. Without that, the reader was told to fix the highlighted fields with nothing
      # highlighted anywhere on the page.
      it "names an error whose attribute the form draws no field for" do
        sign_in_as(create(:user))

        post groups_path, params: { group: { name: "Choraliers", group_type: "orchestra" } }

        expect(response).to have_http_status :unprocessable_content
        expect(page_text(response.body)).to include "Group type is not included in the list"
      end
    end

    # The suite's default host is `www.example.com`, which carries no brand, so the first example
    # here is the control: without it, the whole wiring could be absent and nothing would say so.
    context "when typing the group from the domain it arrived on" do
      it "types the group general on an unbranded host" do
        sign_in_as(create(:user))

        post groups_path, params: { group: { name: "Choraliers" } }

        expect(Group.sole.group_type).to eq("general")
      end

      it "types the group a choir on chorifico.com" do
        host! "chorifico.com"
        sign_in_as(create(:user))

        post groups_path, params: { group: { name: "Choraliers" } }

        expect(Group.sole.group_type).to eq("choir")
      end

      it "types the group a choir on a subdomain of chorifico.com" do
        host! "www.chorifico.com"
        sign_in_as(create(:user))

        post groups_path, params: { group: { name: "Choraliers" } }

        expect(Group.sole.group_type).to eq("choir")
      end

      it "lets a submitted type win over the domain" do
        host! "chorifico.com"
        sign_in_as(create(:user))

        post groups_path, params: { group: { name: "Choraliers", group_type: "band" } }

        expect(Group.sole.group_type).to eq("band")
      end
    end
  end

  describe "PATCH /groups/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        patch group_path(create(:group)), params: { group: { name: "Renamed" } }

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and leaves the group unchanged" do
        group = create(:group, name: "Original")
        sign_in_as(create(:user))

        patch group_path(group), params: { group: { name: "Renamed" } }

        expect(response).to have_http_status :not_found
        expect(group.reload.name).to eq "Original"
      end
    end

    context "when signed in as an owner" do
      it "updates the group" do
        member = create(:member, :active, :owner)
        sign_in_as(member.user)

        patch group_path(member.group), params: { group: { name: "Renamed" } }

        expect(response).to redirect_to group_path(member.group)
        expect(member.group.reload.name).to eq "Renamed"
      end

      it "re-renders the edit page when the group is invalid" do
        member = create(:member, :active, :owner)
        sign_in_as(member.user)

        patch group_path(member.group), params: { group: { name: "" } }

        expect(response).to have_http_status :unprocessable_content
      end
    end

    # The distinction ADR 0003 records, and the one the role rules add: a non-member is told
    # nothing and gets the 404 above, while a member who lacks the role is refused plainly. The
    # refusal is the redirect every other denial gets rather than a bare 403 status, because a
    # refused Turbo submission that lands back on its own form looks like a dead button.
    context "when signed in as a member who does not own the group" do
      it "refuses an ordinary member, and does not answer as a missing record does" do
        member = create(:member, :active, group: create(:group, name: "Original"))
        sign_in_as(member.user)

        patch group_path(member.group), params: { group: { name: "Renamed" } }

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
        expect(member.group.reload.name).to eq "Original"
      end

      it "refuses an administrator, who administers members and not the group itself" do
        member = create(:member, :active, :administrator, group: create(:group, name: "Original"))
        sign_in_as(member.user)

        patch group_path(member.group), params: { group: { name: "Renamed" } }

        expect(response).to redirect_to root_path
        expect(member.group.reload.name).to eq "Original"
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and leaves the group unchanged" do
        member = create(:member, :paused, group: create(:group, name: "Original"))
        sign_in_as(member.user)

        patch group_path(member.group), params: { group: { name: "Renamed" } }

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
        expect(member.group.reload.name).to eq "Original"
      end

      # The submit arrives from the page that refuses it, which is what a browser actually sends and
      # what an earlier redirect_back_or_to got wrong: the referer is the edit form, so the refused
      # member landed back on it and the button looked dead. Setting HTTP_REFERER is the only way a
      # request spec sees that at all.
      it "does not send the refused member back to the page that refused them" do
        member = create(:member, :paused)
        sign_in_as(member.user)

        patch group_path(member.group),
          params: { group: { name: "Renamed" } },
          headers: { "HTTP_REFERER" => edit_group_url(member.group) }

        expect(response).to redirect_to root_path
      end

      # Asserting the rendered page, not flash[:alert]. The value was present in the hash for months
      # while layouts/_flash rendered only `notice`, so every alert in this application was set and
      # silently dropped - the refusal, and the sign-in rate limiter alongside it.
      it "shows the refusal to the member after the redirect" do
        member = create(:member, :paused)
        sign_in_as(member.user)

        patch group_path(member.group), params: { group: { name: "Renamed" } }
        follow_redirect!

        expect(response.body).to include "You are not allowed to do that."
      end
    end

    # The case that was missing when the `on: :create` condition was briefly dropped: the callback
    # then ran on update too, so a blank submitted type was filled from the editing domain instead
    # of being refused, and a choir silently became general.
    context "when the submitted type is blank" do
      it "refuses the update rather than retyping the group from the domain" do
        member = create(:member, :active, :owner)
        member.group.update_column(:group_type, Group.group_types[:choir])
        sign_in_as(member.user)

        patch group_path(member.group), params: { group: { name: "Renamed", group_type: "" } }

        expect(response).to have_http_status :unprocessable_content
        expect(member.group.reload.group_type).to eq("choir")
      end
    end
  end

  describe "DELETE /groups/:id" do
    context "when not signed in" do
      it "redirects to the sign-in page" do
        create(:group)

        expect { delete group_path(Group.sole) }
          .not_to change(Group, :count)

        expect(response).to redirect_to new_session_path
      end
    end

    context "when signed in as a non-member" do
      it "returns 404 and does not destroy the group" do
        group = create(:group)
        sign_in_as(create(:user))

        expect { delete group_path(group) }
          .not_to change(Group, :count)

        expect(response).to have_http_status :not_found
      end
    end

    context "when signed in as an owner" do
      it "destroys the group" do
        member = create(:member, :active, :owner)
        sign_in_as(member.user)

        expect { delete group_path(member.group) }
          .to change(Group, :count).by(-1)

        expect(response).to redirect_to groups_path
      end
    end

    context "when signed in as a member who does not own the group" do
      it "refuses an administrator and does not destroy the group" do
        member = create(:member, :active, :administrator)
        sign_in_as(member.user)

        expect { delete group_path(member.group) }
          .not_to change(Group, :count)

        expect(response).to redirect_to root_path
      end
    end

    context "when signed in as a paused member" do
      it "refuses with a redirect carrying an alert, and does not destroy the group" do
        member = create(:member, :paused)
        sign_in_as(member.user)

        expect { delete group_path(member.group) }
          .not_to change(Group, :count)

        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end
    end
  end

  # The refusal and a genuinely missing record must be the same response, not merely the same
  # status. `head :not_found` sent zero bytes while an absent id renders the 404 page, so the two
  # were trivially distinguishable by body length and the existence oracle ADR 0003 chose 404 over
  # 403 to close stayed open.
  describe "a refused group and a missing one" do
    # Rendered the way production renders, because the test environment does not: it answers both
    # with its debug page, and two different exceptions produce two different debug pages, so the
    # comparison would fail for a reason that has nothing to do with the oracle. Production renders
    # public/404.html for both, which is the whole point of raising rather than `head`. Restored in
    # an ensure so the suite still passes in any order.
    around do |example|
      original = Rails.application.env_config.slice(
        "action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions"
      )
      Rails.application.env_config["action_dispatch.show_exceptions"] = :all
      Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false

      example.run
    ensure
      Rails.application.env_config.merge!(original)
    end

    it "answer identically" do
      non_member = create(:member)
      sign_in_as(non_member.user)

      get group_path(create(:group))
      refused = [ response.status, response.body.bytesize ]

      get "/groups/#{Group.maximum(:id) + 1}"
      missing = [ response.status, response.body.bytesize ]

      expect(refused).to eq missing
    end
  end


  # A relation_scope is not a rule, so the pre-checks never run for it: every scope asked
  # `user.groups`, which is every group ever joined. The list leaked what the detail page refused.
  describe "an inactive member's group list" do
    it "does not include the group they left" do
      actor = create(:member, :inactive, group: create(:group, name: "Left Behind"))
      sign_in_as(actor.user)

      get groups_path

      # dom_id rather than the name: `_group.html.erb` renders `group.name.upcase`, so asserting
      # the name passes against a page that lists the group in capitals. Watched doing exactly
      # that, with the defect fully restored.
      expect(response.body).not_to include "group_#{actor.group_id}"
    end
  end
end
