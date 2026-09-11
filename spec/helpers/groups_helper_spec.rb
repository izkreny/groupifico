require 'rails_helper'

RSpec.describe GroupsHelper, type: :helper do
  describe "#next_event_line" do
    # `freeze_time` because `Group#next_event` filters on `upcoming`, so an example that names a
    # date without pinning now passes or fails on when the suite reaches this file.
    it "names the day the group next meets, with no clock time" do
      freeze_time do
        group = create(:group)
        create(:event, group:, status: :confirmed,
          starts_at: 2.days.from_now.change(hour: 19), ends_at: 2.days.from_now.change(hour: 21))

        expect(helper.next_event_line(group)).to eq "next: #{2.days.from_now.strftime('%a %-d %b')}"
      end
    end

    it "says nothing is scheduled for a group with no next event" do
      expect(helper.next_event_line(create(:group))).to eq "nothing scheduled"
    end
  end
end
