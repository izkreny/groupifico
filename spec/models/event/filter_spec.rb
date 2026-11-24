require "rails_helper"

RSpec.describe Event::Filter do
  let(:member) { create(:member, :active) }

  def upcoming(**attributes)
    create(:event, :from_the_future, group: member.group, creator: member, status: :confirmed, **attributes)
  end

  def names(filter)
    filter.apply(member.group.events).map(&:name)
  end

  describe ".from" do
    # WHY: #460 AC10. The URL is the only place a filter lives, so a link's parameters are the whole filter.
    it "reads the list and filters from the URL's parameters" do
      filter = described_class.from(member, ActionController::Parameters.new(scope: "past", category: %w[ rehearsal gig ], answer: %w[ not_answered ]), may_edit: false, may_answer: true)

      expect([ filter.scope, filter.categories, filter.answers ]).to eq [ "past", %w[ gig rehearsal ], %w[ not_answered ] ]
    end

    # WHY: #460 AC9. A URL with no filter in it is Upcoming with nothing on.
    it "is Upcoming with no filters when the URL carries none" do
      filter = described_class.from(member, ActionController::Parameters.new(group_id: member.group_id), may_edit: false, may_answer: true)

      expect([ filter.scope, filter.categories, filter.answers, filter.managed?, filter.narrowed? ]).to eq [ nil, [], [], false, false ]
    end

    # WHY: #462 AC3. Upcoming stays the default for a member who oversees the events too, To do being a tab they open rather than the one they land on.
    it "is Upcoming for a member who oversees the events when the URL names no list" do
      filter = described_class.from(member, ActionController::Parameters.new(group_id: member.group_id), may_edit: true, may_answer: true)

      expect(filter.scope).to be_nil
    end
  end

  describe "#offered_tabs" do
    # WHY: GHI-502 AC1. To do comes third, after Past, for every member, since it lists what waits on that member; compared as pairs because a hash compares equal whatever its order.
    it "offers To do third, after Past, to a member who does not oversee the events" do
      expect(described_class.new(member).offered_tabs.to_a).to eq [ [ nil, "Upcoming" ], [ "past", "Past" ], [ "to_do", "To do" ], [ "canceled", "Canceled" ] ]
    end
  end

  describe ".new" do
    context "with values the list does not offer" do
      # WHY: #460 AC11. A value outside the sheet's choices is ignored, so it narrows nothing and can never be written back.
      it "drops a list, a category and an answer the sheet does not offer" do
        filter = described_class.new(member, scope: "archived", categories: %w[ gig party ], answers: %w[ yes perhaps ])

        expect([ filter.scope, filter.categories, filter.answers ]).to eq [ nil, %w[ gig ], %w[ yes ] ]
      end

      # WHY: #460 AC3 and AC11. "Managed by me" is offered only to someone who manages one of the group's events, so anyone else's is dropped.
      it "drops the managed filter for a member who manages none of the group's events" do
        filter = described_class.new(member, managed: "1")

        expect([ filter.managed_offered?, filter.managed? ]).to eq [ false, false ]
      end

      it "keeps the managed filter for a member who manages one of the group's events" do
        upcoming(manager: member)

        filter = described_class.new(member, managed: "1")

        expect([ filter.managed_offered?, filter.managed? ]).to eq [ true, true ]
      end

      # WHY: #460 AC11. The sheet sends "1" and nothing else, so any other value is one the list does not offer.
      it "drops a managed value the sheet does not send" do
        upcoming(manager: member)

        expect([ described_class.new(member, managed: "no").managed?, described_class.new(member, managed: "banana").managed? ]).to eq [ false, false ]
      end
    end
  end

  describe "#apply" do
    it "narrows the upcoming list to the categories picked" do
      upcoming(name: "Advent concert", category: :gig)
      upcoming(name: "Section rehearsal", category: :rehearsal)

      expect(names(described_class.new(member, categories: %w[ gig ]))).to eq [ "Advent concert" ]
    end

    # WHY: #460 AC3. Choosing it narrows the list to the events the member manages.
    it "narrows the list to the events the member manages" do
      upcoming(name: "Advent concert", manager: member)
      upcoming(name: "Christmas concert")

      expect(names(described_class.new(member, managed: "1"))).to eq [ "Advent concert" ]
    end

    it "narrows the list to the events the member answered as picked" do
      create(:registration, member:, event: upcoming(name: "Advent concert"), status: :yes)
      create(:registration, member:, event: upcoming(name: "Christmas concert"), status: :no)

      expect(names(described_class.new(member, answers: %w[ yes ]))).to eq [ "Advent concert" ]
    end

    # WHY: "Not answered" is a place on the list with no answer yet, so an event the member is not listed on has nothing of theirs to match.
    it "counts a held place and a waiting request as not answered, and an event the member is not listed on as neither" do
      create(:registration, member:, event: upcoming(name: "Advent concert", starts_at: 10.days.from_now), status: :reserved)
      create(:registration, member:, event: upcoming(name: "Christmas concert", starts_at: 20.days.from_now), status: :response_requested)
      upcoming(name: "New year's gig")

      expect(names(described_class.new(member, answers: %w[ not_answered ]))).to eq [ "Advent concert", "Christmas concert" ]
    end

    it "keeps the filters on another list" do
      create(:event, :from_the_past, group: member.group, creator: member, name: "Autumn fair", category: :gig)
      create(:event, :from_the_past, group: member.group, creator: member, name: "Full rehearsal", category: :rehearsal)

      expect(names(described_class.new(member, scope: "past", categories: %w[ gig ]))).to eq [ "Autumn fair" ]
    end

    # WHY: #462 AC1. Every unconfirmed event, ahead or ended, and every ended one still confirmed, oldest first so the longest waiting leads; nothing concluded, and no confirmed event still ahead.
    it "lists on To do every unconfirmed event and every ended one still confirmed, oldest first" do
      create(:event, group: member.group, creator: member, name: "Autumn fair", status: :unconfirmed, starts_at: 20.days.ago, ends_at: 20.days.ago + 2.hours)
      create(:event, group: member.group, creator: member, name: "Harvest gig", status: :confirmed, starts_at: 5.days.ago, ends_at: 5.days.ago + 2.hours)
      create(:event, group: member.group, creator: member, name: "Summer gig", status: :concluded, starts_at: 10.days.ago, ends_at: 10.days.ago + 2.hours)
      upcoming(name: "Winter gala", status: :unconfirmed, starts_at: 9.days.from_now, ends_at: 9.days.from_now + 2.hours)
      upcoming(name: "Advent concert")

      expect(names(described_class.new(member, may_edit: true, scope: "to_do"))).to eq [ "Autumn fair", "Harvest gig", "Winter gala" ]
    end

    # WHY: #462 AC6. The sheet's filters narrow To do like any other list.
    it "narrows To do to the categories picked" do
      create(:event, :from_the_past, group: member.group, creator: member, name: "Autumn fair", category: :gig, status: :confirmed)
      create(:event, :from_the_past, group: member.group, creator: member, name: "Full rehearsal", category: :rehearsal, status: :confirmed)

      expect(names(described_class.new(member, may_edit: true, scope: "to_do", categories: %w[ gig ]))).to eq [ "Autumn fair" ]
    end

    context "with the questions put to the member" do
      # WHY: an ended event still confirmed and an unconfirmed one ahead, which wait on whoever runs the events, beside a question this member has not answered on each side of today, a maybe on an ended event and a held place ahead, which asks nothing yet.
      before do
        create(:event, :from_the_past, group: member.group, creator: member, name: "Harvest gig", status: :confirmed, starts_at: 5.days.ago.change(hour: 18))
        upcoming(name: "Winter gala", status: :unconfirmed, starts_at: 9.days.from_now.change(hour: 18))
        create(:registration, member:, event: upcoming(name: "Advent concert", starts_at: 20.days.from_now.change(hour: 18)), status: :response_requested)
        create(:registration, member:, event: upcoming(name: "Christmas concert", starts_at: 30.days.from_now.change(hour: 18)), status: :reserved)
        unsure = create(:event, group: member.group, creator: member, name: "Autumn fair", status: :confirmed, starts_at: 20.days.ago.change(hour: 18), ends_at: 20.days.ago.change(hour: 20))
        travel_to(unsure.starts_at - 1.day) { create(:registration, member:, event: unsure, status: :maybe) }
        requested = upcoming(name: "New year's gig", status: :unconfirmed, starts_at: 40.days.from_now.change(hour: 18))
        create(:registration, member:, event: requested, status: :response_requested)
      end

      # WHY: GHI-502 AC2, AC3 and AC6. A member who does not oversee the events gets the events whose row asks them a question, oldest first, and none of the events waiting on whoever runs them.
      it "lists on To do the events asking the member a question, oldest first" do
        expect(names(described_class.new(member, may_answer: true, scope: "to_do"))).to eq [ "Autumn fair", "Advent concert", "New year's gig" ]
      end

      # WHY: GHI-502 AC5 and AC6. A member who also runs the events gets both reasons in one list, oldest first, the unconfirmed event that also asks them a question listed once.
      it "lists on To do both reasons in one list for a member who oversees the events" do
        expect(names(described_class.new(member, may_answer: true, may_edit: true, scope: "to_do"))).to eq [ "Autumn fair", "Harvest gig", "Winter gala", "Advent concert", "New year's gig" ]
      end

      # WHY: GHI-502 Q1 on #526. A paused member may not answer, so no row asks them anything and their own reason adds nothing.
      it "leaves the member's own questions off To do while they may not answer" do
        expect(names(described_class.new(member, scope: "to_do"))).to be_empty
      end
    end
  end

  describe "#counts" do
    # WHY: #484 AC12. Each tab counts what it would list with every filter on, and a list with nothing on it counts zero rather than dropping out.
    it "counts each list under the filters that are on, a list with none of them at zero" do
      upcoming(name: "Advent concert", category: :gig)
      upcoming(name: "Section rehearsal", category: :rehearsal)
      create(:event, :from_the_past, group: member.group, creator: member, name: "Autumn fair", category: :gig)

      expect(described_class.new(member, categories: %w[ gig ]).counts(member.group.events)).to eq({ nil => 1, "past" => 1, "to_do" => 0, "canceled" => 0 })
    end

    # WHY: #462 AC8. To do carries its count like every other tab, an event on it counted on its dated list too.
    it "counts To do beside the other lists for a member who oversees the events" do
      upcoming(name: "Advent concert", category: :gig)
      create(:event, :from_the_past, group: member.group, creator: member, name: "Autumn fair", category: :gig, status: :confirmed)
      create(:event, :from_the_past, group: member.group, creator: member, name: "Summer gig", category: :gig, status: :concluded)

      expect(described_class.new(member, may_edit: true, categories: %w[ gig ]).counts(member.group.events)).to eq({ nil => 1, "to_do" => 1, "past" => 2, "canceled" => 0 })
    end
  end

  describe "#narrowed?" do
    # WHY: #460 AC7. The funnel says whether anything hides events from the list picked, and the list itself never does.
    it "is false for a list alone and true once a filter is on" do
      expect([ described_class.new(member, scope: "past").narrowed?, described_class.new(member, scope: "past", answers: %w[ maybe ]).narrowed? ]).to eq [ false, true ]
    end

    # WHY: #460 AC7 names the managed filter as one of the three that turn the funnel primary.
    it "is true with only the managed filter on" do
      upcoming(manager: member)

      expect(described_class.new(member, managed: "1").narrowed?).to be true
    end
  end

  describe "#cleared" do
    # WHY: #460 AC5. Clear all drops every filter and keeps the tab, since the tab is not a filter.
    it "keeps the list and nothing else" do
      expect(described_class.new(member, scope: "past", categories: %w[ gig ], answers: %w[ yes ]).cleared).to eq({ scope: "past" })
    end
  end

  describe "#chips" do
    it "names each filter in sheet order, with the parameters that remove it alone" do
      filter = described_class.new(member, scope: "past", categories: %w[ rehearsal gig ], answers: %w[ no ])

      expect(filter.chips).to eq [
        [ "Gig", { scope: "past", category: %w[ rehearsal ], answer: %w[ no ] } ],
        [ "Rehearsal", { scope: "past", category: %w[ gig ], answer: %w[ no ] } ],
        [ "No", { scope: "past", category: %w[ gig rehearsal ] } ]
      ]
    end

    # WHY: #460 AC5. The managed chip's ✕ has to drop the managed filter alone, like every other chip's.
    it "gives the managed chip the parameters that drop it alone" do
      upcoming(manager: member)

      expect(described_class.new(member, categories: %w[ gig ], managed: "1").chips).to eq [
        [ "Gig", { managed: "1" } ],
        [ "Managed by me", { category: %w[ gig ] } ]
      ]
    end
  end
end
