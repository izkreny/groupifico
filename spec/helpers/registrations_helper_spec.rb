require 'rails_helper'

RSpec.describe RegistrationsHelper, type: :helper do
  describe "#members_available" do
    it "returns the group's members who are not already attending the event" do
      event    = create(:event)
      attendee = create(:member, group: event.group)
      create(:registration, event:, member: attendee)

      expect(helper.members_available(event.group, event)).to contain_exactly(event.creator)
    end

    it "returns no members when every member of the group is already attending" do
      event = create(:event)
      create(:registration, event:, member: event.creator)

      expect(helper.members_available(event.group, event)).to be_empty
    end
  end
end
