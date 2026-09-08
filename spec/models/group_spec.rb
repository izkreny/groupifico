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
    describe "the group_type default" do
      it "is general when no brand has been resolved" do
        expect(described_class.new.group_type).to eq("general")
      end

      it "is choir under the chorifico.com brand" do
        Current.set(brand: Brand.new("chorifico.com")) do
          expect(described_class.new.group_type).to eq("choir")
        end
      end

      it "yields to an explicitly given type" do
        Current.set(brand: Brand.new("chorifico.com")) do
          expect(described_class.new(group_type: :band).group_type).to eq("band")
        end
      end

      # The value is resolved when it is first read rather than at `Group.new`, so a record built
      # before the brand was known still answers for the brand in force at the read. Both creation
      # routes read it inside the request - `save` runs the validation that reads it - so this is
      # the mechanism working; it is pinned because a record carried out of its request and read
      # there would resolve against whatever brand is current then.
      it "is resolved when the value is first read, not at instantiation" do
        built_before_any_brand = described_class.new

        resolved = Current.set(brand: Brand.new("chorifico.com")) { built_before_any_brand.group_type }

        expect(resolved).to eq("choir")
      end

      # The other half of the same fact, and the more important one: once read, the type is the
      # record's own and no later brand moves it.
      it "keeps the type it first resolved" do
        group = described_class.new
        group.group_type

        resolved = Current.set(brand: Brand.new("chorifico.com")) { group.group_type }

        expect(resolved).to eq("general")
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
