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

    it "omits a pending member, who has not been let into the group yet" do
      event = create(:event)
      create(:member, :pending, group: event.group)

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

  describe "#list_tally" do
    it "counts the active members who have a registration against every active member" do
      event = create(:event)
      create(:member, :active, group: event.group)
      create(:registration, event:, member: event.creator)

      expect(helper.list_tally(event.group, event)).to eq "1 of 2 active members are on the list."
    end

    it "counts neither a paused nor an inactive member on either side" do
      event = create(:event)
      create(:registration, event:, member: create(:member, :paused, group: event.group))
      create(:registration, event:, member: create(:member, :inactive, group: event.group))

      expect(helper.list_tally(event.group, event)).to eq "0 of 1 active members are on the list."
    end
  end

  describe "#not_active_on_list_line" do
    it "counts the paused and the inactive members on the list in one sentence" do
      event = create(:event)
      2.times { create(:registration, event:, member: create(:member, :paused, group: event.group)) }
      create(:registration, event:, member: create(:member, :inactive, group: event.group))

      expect(helper.not_active_on_list_line(event)).to eq "2 paused, and 1 inactive members are on the list too."
    end

    it "names only the kind the list holds, in the singular for one" do
      event = create(:event)
      create(:registration, event:, member: create(:member, :paused, group: event.group))

      expect(helper.not_active_on_list_line(event)).to eq "1 paused member is on the list too."
    end

    # A paused member off the list is not on it, so nothing is said about them here.
    it "is nil when everybody on the list is active" do
      event = create(:event)
      create(:registration, event:, member: create(:member, :active, group: event.group))
      create(:member, :paused, group: event.group)

      expect(helper.not_active_on_list_line(event)).to be_nil
    end
  end

  describe "#registration_status_label" do
    it "names an answer by the answer itself" do
      expect(helper.registration_status_label(build(:registration, status: :maybe))).to eq "Maybe"
    end

    # The badge is the row's only statement of where it stands, so the two unanswered statuses
    # are spelled out rather than left as the enum's own words.
    it "reads a requested registration as a question still waiting" do
      expect(helper.registration_status_label(build(:registration, status: :response_requested))).to eq "Response requested"
    end

    it "reads a reserved registration as a place held before any request" do
      expect(helper.registration_status_label(build(:registration, status: :reserved))).to eq "Place reserved, no response requested yet"
    end
  end
end
