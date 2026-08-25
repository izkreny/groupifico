require 'rails_helper'

RSpec.describe RegistrationsHelper, type: :helper do
  describe "#members_available" do
    it "returns the group's members who are not already attending the event" do
      group    = create(:group)
      event    = create(:event, group:)
      attendee = create(:member, group:)
      other    = create(:member, group:)
      create(:registration, event:, member: attendee)

      expect(helper.members_available(group, event)).to contain_exactly(other, event.creator)
    end

    it "returns no members when every member of the group is already attending" do
      group = create(:group)
      event = create(:event, group:)
      create(:registration, event:, member: event.creator)

      expect(helper.members_available(group, event)).to be_empty
    end
  end
end
