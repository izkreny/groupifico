require 'rails_helper'

RSpec.describe Group, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:address).optional.touch(true) }
    it { is_expected.to have_many(:members).dependent(:destroy) }
    it { is_expected.to have_many(:events).dependent(:destroy) }
    it { is_expected.to have_many(:events_addresses).through(:events).source(:address) }
    it { is_expected.to accept_nested_attributes_for(:address) }

    describe "nested attributes for address with ':reject_if' option" do
      it "does not build an address if all provided address attributes are empty" do
        group = build(:group, address_attributes: { name: "", city: "" })

        expect(group.address).to be_nil
      end

      it "builds an address if at least one of the provided address attributes is not empty" do
        group = build(:group, address_attributes: { name: "", city: "Ur" })

        expect(group.address).not_to be_nil
      end
    end
  end

  describe "(enums)" do
    it { is_expected.to define_enum_for(:group_type).with_values(general: 0, choir: 1, band: 2).validating }

    # Hand-rolled rather than `with_default`, which asserts a value and so passes just as happily
    # against a fixed `default: :general`. What matters is that the value tracks the brand, and
    # only a pair of examples under different brands can say that.
    #
    # Each one validates, because the type is settled in a `before_validation` rather than by an
    # enum default: an unvalidated `Group.new` carries no type at all.
    describe "the group_type taken from the brand" do
      it "is general when no brand has been resolved" do
        group = build(:group)

        group.valid?

        expect(group.group_type).to eq("general")
      end

      it "is choir under the chorifico.com brand" do
        Current.set(brand: Brand.new("chorifico.com")) do
          group = build(:group)

          group.valid?

          expect(group.group_type).to eq("choir")
        end
      end

      it "yields to an explicitly given type" do
        Current.set(brand: Brand.new("chorifico.com")) do
          group = build(:group, group_type: :band)

          group.valid?

          expect(group.group_type).to eq("band")
        end
      end
    end
  end

  describe "(validations)" do
    it "is invalid if the address is not valid" do
      valid_group_with_invalid_address = build(:group, address: build(:address, name: ""))

      expect(valid_group_with_invalid_address).to be_invalid
    end

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(250) }
    it { is_expected.to validate_length_of(:description).is_at_most(25_000) }
  end

  describe "#save" do
    it "persists neither the group nor a member it carries that cannot be saved" do
      group_count  = described_class.count
      member_count = Member.count

      group = build(:group)
      group.members.build
      group.save

      expect(described_class.count).to eq group_count
      expect(Member.count).to eq member_count
    end
  end

  describe "#events_addresses" do
    let(:group) { build(:group) }

    it "returns an empty array if there are no events" do
      expect(group.events_addresses).to be_empty
    end

    it "returns an empty array if the events do not have addresses" do
      create(:event, group:)

      expect(group.events_addresses).to be_empty
    end

    context "when all events share one address" do
      let(:address) { build(:address) }

      it "returns that specific address exactly once" do
        create_list(:event, 2, group:, address:)

        expect(group.events_addresses).to contain_exactly(address)
      end
    end

    context "when each event has a unique address" do
      it "returns exactly those specific addresses" do
        first_address, second_address = build_list(:address, 2)
        create(:event, group:, address: first_address)
        create(:event, group:, address: second_address)

        expect(group.events_addresses).to contain_exactly(first_address, second_address)
      end
    end
  end

  describe "#addresses" do
    context "when the group has an address" do
      let(:group_address)      { build(:address) }
      let(:event_address)      { build(:address) }
      let(:group_with_address) { create(:group, address: group_address) }

      it "returns the events' addresses combined with the group's address if they differ" do
        create(:event, group: group_with_address, address: event_address)

        expect(group_with_address.addresses).to contain_exactly(event_address, group_address)
      end

      it "returns only the group address if it is also used by all events" do
        create(:event, group: group_with_address, address: group_address)

        expect(group_with_address.addresses).to contain_exactly(group_address)
      end
    end

    context "when the group does not have an address" do
      let(:event_address)         { build(:address) }
      let(:group_without_address) { create(:group) }

      it "returns just the events' addresses" do
        create(:event, group: group_without_address, address: event_address)

        expect(group_without_address.addresses).to contain_exactly(event_address)
      end
    end
  end

  # Times are frozen so "upcoming" cannot depend on how long the suite takes to reach this file.
  describe "#featured_event" do
    it "is the event already running, ahead of one that starts sooner than it ends" do
      freeze_time do
        group = create(:group)
        creator = create(:member, group:)
        create(:event, group:, creator:, status: :confirmed, starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour)
        running = create(:event, group:, creator:, status: :confirmed, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)

        expect(group.featured_event).to eq running
      end
    end

    it "falls back to the soonest upcoming event when nothing is running" do
      freeze_time do
        group = create(:group)
        creator = create(:member, group:)
        create(:event, group:, creator:, status: :confirmed, starts_at: 10.days.from_now, ends_at: 10.days.from_now + 1.hour)
        soonest = create(:event, group:, creator:, status: :confirmed, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour)

        expect(group.featured_event).to eq soonest
      end
    end

    # The same `confirmed` filter `#next_event` applies, asserted here too: an event running right
    # now is still not a commitment until somebody confirms it.
    it "ignores an unconfirmed event, however far under way" do
      freeze_time do
        group = create(:group)
        creator = create(:member, group:)
        create(:event, group:, creator:, status: :unconfirmed, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)

        expect(group.featured_event).to be_nil
      end
    end

    it "ignores an event that has ended" do
      freeze_time do
        group = create(:group)
        creator = create(:member, group:)
        create(:event, group:, creator:, status: :confirmed, starts_at: 2.days.ago, ends_at: 2.days.ago + 1.hour)

        expect(group.featured_event).to be_nil
      end
    end
  end

  describe "#next_event" do
    it "is the soonest of the group's confirmed upcoming events" do
      freeze_time do
        group = create(:group)
        creator = create(:member, group:)
        create(:event, group:, creator:, status: :confirmed, starts_at: 10.days.from_now, ends_at: 10.days.from_now + 1.hour)
        soonest = create(:event, group:, creator:, status: :confirmed, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour)

        expect(group.next_event).to eq soonest
      end
    end

    it "ignores an event that has already started" do
      freeze_time do
        group = create(:group)
        creator = create(:member, group:)
        create(:event, group:, creator:, status: :confirmed, starts_at: 2.days.ago, ends_at: 2.days.ago + 1.hour)

        expect(group.next_event).to be_nil
      end
    end

    it "ignores a canceled event, however soon it starts" do
      freeze_time do
        group = create(:group)
        creator = create(:member, group:)
        create(:event, group:, creator:, status: :canceled, starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour)
        confirmed = create(:event, group:, creator:, status: :confirmed, starts_at: 5.days.from_now, ends_at: 5.days.from_now + 1.hour)

        expect(group.next_event).to eq confirmed
      end
    end

    it "ignores an event nobody has confirmed yet" do
      freeze_time do
        group = create(:group)
        creator = create(:member, group:)
        create(:event, group:, creator:, status: :unconfirmed, starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour)

        expect(group.next_event).to be_nil
      end
    end

    it "is nil for a group with no events at all" do
      expect(create(:group).next_event).to be_nil
    end
  end

  describe "#current_members" do
    it "counts an active and a paused member, and not one who has left" do
      group = create(:group)
      create(:member, :active, group:)
      create(:member, :paused, group:)
      create(:member, :inactive, group:)

      expect(group.current_members.count).to eq 2
    end
  end

  describe "#owned_by_anyone_but?" do
    it "answers false when the named member is the group's only owner" do
      group = create(:group)
      owner = create(:member, :owner, group:)
      create(:member, :administrator, group:)

      expect(group.owned_by_anyone_but?(owner)).to be false
    end

    it "answers true when another member owns the group as well" do
      group = create(:group)
      owner = create(:member, :owner, group:)
      create(:member, :owner, group:)

      expect(group.owned_by_anyone_but?(owner)).to be true
    end
  end
end
