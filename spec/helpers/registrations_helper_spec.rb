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

  describe "#registration_status_label" do
    it "names an answer by the answer itself" do
      expect(helper.registration_status_label(build(:registration, status: :maybe))).to eq "Maybe"
    end

    # The badge is the row's only statement of where it stands, so the two unanswered statuses
    # are spelled out rather than left as the enum's own words.
    it "reads an invited registration as a question still waiting" do
      expect(helper.registration_status_label(build(:registration, status: :invited))).to eq "Invited, no reply yet"
    end

    it "reads a reserved registration as a place held before anybody asked" do
      expect(helper.registration_status_label(build(:registration, status: :reserved))).to eq "Place reserved, not asked yet"
    end
  end

  describe "#left_out_line" do
    it "names the paused member who has no registration on the event" do
      event = create(:event)
      create(:member, :paused, group: event.group, user: create(:user, email: "dan@example.com"))

      expect(helper.left_out_line(event.group, event)).to eq "dan is paused, left out"
    end

    it "names several paused members in one sentence, by name" do
      event = create(:event)
      create(:member, :paused, group: event.group, user: create(:user, email: "fay@example.com"))
      create(:member, :paused, group: event.group, user: create(:user, email: "dan@example.com"))

      expect(helper.left_out_line(event.group, event)).to eq "dan and fay are paused, left out"
    end

    # A paused member already on the list has a row of their own, and an inactive one has left the
    # group, so neither is somebody the roster leaves out.
    it "is nil when no paused member is missing from the list" do
      event = create(:event)
      create(:registration, event:, member: create(:member, :paused, group: event.group))
      create(:member, :inactive, group: event.group)

      expect(helper.left_out_line(event.group, event)).to be_nil
    end
  end
end
