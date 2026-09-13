require 'rails_helper'

RSpec.describe RegistrationsHelper, type: :helper do
  describe "#members_available" do
    it "returns the group's members who have no registration on the event" do
      event    = create(:event)
      attendee = create(:member, group: event.group)
      create(:registration, event:, member: attendee)

      expect(helper.members_available(event.group, event)).to contain_exactly(event.creator)
    end

    it "returns no members when every member of the group is already registered" do
      event = create(:event)
      create(:registration, event:, member: event.creator)

      expect(helper.members_available(event.group, event)).to be_empty
    end

    it "lists a paused member, who is shown and cannot be ticked" do
      event  = create(:event)
      paused = create(:member, :paused, group: event.group)

      expect(helper.members_available(event.group, event)).to include(paused)
    end

    it "omits an inactive member, who has left the group" do
      event = create(:event)
      create(:member, :inactive, group: event.group)

      expect(helper.members_available(event.group, event)).to contain_exactly(event.creator)
    end

    # The paused member is created first, so insertion order alone would list them first and an
    # unordered relation passes this example for the wrong reason.
    it "orders the tickable members before the paused ones" do
      group  = create(:group)
      paused = create(:member, :paused, group:)
      event  = create(:event, group:)

      expect(helper.members_available(group, event)).to eq [ event.creator, paused ]
    end
  end

  describe "#invited_tally" do
    it "counts the active members who have a registration against every active member" do
      event = create(:event)
      create(:member, :active, group: event.group)
      create(:registration, event:, member: event.creator)

      expect(helper.invited_tally(event.group, event)).to eq "1 of 2 invited"
    end

    it "counts neither a paused nor an inactive member on either side" do
      event = create(:event)
      create(:registration, event:, member: create(:member, :paused, group: event.group))
      create(:registration, event:, member: create(:member, :inactive, group: event.group))

      expect(helper.invited_tally(event.group, event)).to eq "0 of 1 invited"
    end
  end
end
