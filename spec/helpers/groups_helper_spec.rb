require "rails_helper"

RSpec.describe GroupsHelper, type: :helper do
  describe "#group_type_choices" do
    it "offers the three types in the order frame 2e fixes, not the enum's" do
      expect(helper.group_type_choices).to eq [ [ "Choir", "choir" ], [ "Band", "band" ], [ "General", "general" ] ]
    end

    # The check that replaces a sorting hook for a fourth type: the only screen that sets
    # `group_type` reads this list, so a type added to `Group` and not placed here would simply
    # never be offered. Watched failing with `choir` removed from the list.
    it "covers every type the model defines" do
      expect(helper.group_type_choices.map(&:last)).to match_array Group.group_types.keys
    end
  end

  describe "#featured_event_line" do
    # `freeze_time` because `Group#featured_event` filters on the clock, so an example that names a
    # date without pinning now passes or fails on when the suite reaches this file.
    it "names the day the group next meets, with no clock time" do
      freeze_time do
        group = create(:group)
        create(:event, group:, status: :confirmed,
          starts_at: 2.days.from_now.change(hour: 19), ends_at: 2.days.from_now.change(hour: 21))

        expect(helper.featured_event_line(group)).to eq "next: #{2.days.from_now.strftime('%a %-d %b')}"
      end
    end

    # A date is the wrong answer while the event is on: the day it names has arrived, so the card
    # would read as one that failed to refresh.
    it "says the group is meeting right now for an event under way" do
      freeze_time do
        group = create(:group)
        create(:event, group:, status: :confirmed, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)

        expect(helper.featured_event_line(group)).to eq "happening now"
      end
    end

    it "says nothing is scheduled for a group with no event ahead of it" do
      expect(helper.featured_event_line(create(:group))).to eq "nothing scheduled"
    end
  end
end
