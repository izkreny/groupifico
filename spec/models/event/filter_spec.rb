require "rails_helper"

RSpec.describe Event::Filter do
  let(:member) { create(:member, :active) }

  def upcoming(**attributes)
    create(:event, :from_the_future, group: member.group, creator: member, status: :confirmed, **attributes)
  end

  def names(filter)
    filter.apply(member.group.events).map(&:name)
  end

  describe ".read" do
    # WHY: #460 AC10. A link carrying a filter shows it for that visit, so the URL wins over what the cookies saved, wholesale rather than merged.
    it "reads the URL rather than the cookies when the URL carries a filter" do
      filter = described_class.read(member, params: ActionController::Parameters.new(category: [ "gig" ]), cookies: { events_list: "past", events_answers: "yes" })

      expect([ filter.list, filter.categories, filter.answers ]).to eq [ nil, %w[ gig ], [] ]
    end

    # WHY: #460 AC9. With nothing in the URL, the list and filters a member applied are what the screen shows.
    it "reads the cookies when the URL carries no filter" do
      filter = described_class.read(member, params: ActionController::Parameters.new(group_id: member.group_id), cookies: { events_list: "past", events_categories: "rehearsal,gig", events_answers: "not_answered" })

      expect([ filter.list, filter.categories, filter.answers ]).to eq [ "past", %w[ gig rehearsal ], %w[ not_answered ] ]
    end
  end

  describe "values the list does not offer" do
    # WHY: #460 AC11. A value outside the sheet's choices is ignored, so it narrows nothing and can never be written back.
    it "drops a list, a category and an answer the sheet does not offer" do
      filter = described_class.new(member, list: "archived", categories: %w[ gig party ], answers: %w[ yes perhaps ])

      expect([ filter.list, filter.categories, filter.answers ]).to eq [ nil, %w[ gig ], %w[ yes ] ]
    end

    # WHY: #460 AC3 and AC11. "Only events I manage" is offered only to someone who manages one of the group's events, so anyone else's is dropped.
    it "drops the managed filter for a member who manages none of the group's events" do
      filter = described_class.new(member, managed: "1")

      expect([ filter.managed_offered?, filter.managed? ]).to eq [ false, false ]
    end

    it "keeps the managed filter for a member who manages one of the group's events" do
      upcoming(manager: member)

      filter = described_class.new(member, managed: "1")

      expect([ filter.managed_offered?, filter.managed? ]).to eq [ true, true ]
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

      expect(names(described_class.new(member, list: "past", categories: %w[ gig ]))).to eq [ "Autumn fair" ]
    end
  end

  describe "#narrowed?" do
    # WHY: #460 AC7. The funnel says whether anything hides events from the list picked, and the list itself never does.
    it "is false for a list alone and true once a filter is on" do
      expect([ described_class.new(member, list: "past").narrowed?, described_class.new(member, list: "past", answers: %w[ maybe ]).narrowed? ]).to eq [ false, true ]
    end
  end

  describe "#chips" do
    it "names each filter in sheet order, with the parameters that remove it alone" do
      filter = described_class.new(member, list: "past", categories: %w[ rehearsal gig ], answers: %w[ no ])

      expect(filter.chips).to eq [
        [ "Gig", { scope: "past", category: %w[ rehearsal ], answer: %w[ no ] } ],
        [ "Rehearsal", { scope: "past", category: %w[ gig ], answer: %w[ no ] } ],
        [ "No", { scope: "past", category: %w[ gig rehearsal ] } ]
      ]
    end
  end

  describe "#to_cookies" do
    it "names what is on and leaves what is not blank, so the cookies read back as the same filter" do
      filter = described_class.new(member, list: "canceled", categories: %w[ other rehearsal ])

      expect(filter.to_cookies).to eq(events_list: "canceled", events_categories: "rehearsal,other", events_answers: "", events_managed: nil)
    end
  end
end
