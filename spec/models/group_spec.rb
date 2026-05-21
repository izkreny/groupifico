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

      it "builds an address if at least one address attribute is present" do
        group = build(:group, address_attributes: { name: "", city: "Ur" })
        expect(group.address).not_to be_nil
      end
    end
  end

  describe "(enums)" do
    it { is_expected.to define_enum_for(:group_type).with_values(general: 0, choir: 1, band: 2).with_default(:choir).validating }
  end

  describe "(validations)" do
    it "is invalid if the associated address is not valid" do
      valid_group_with_invalid_address = build(:group, address: build(:address, name: ""))
      expect(valid_group_with_invalid_address).to be_invalid
    end

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(250) }
    it { is_expected.to validate_length_of(:description).is_at_most(25_000) }
  end

  describe "#events_addresses" do
    let(:group) { build(:group) }

    it "returns an empty array if there are no associated events" do
      expect(group.events_addresses).to be_empty
    end

    it "returns an empty array if the associated events do not have associated addresses" do
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
    let(:group) { build(:group, address: group_address) }
    let(:events_addresses_mock) { [ build(:address) ] }

    before do
      allow(group).to receive(:events_addresses).and_return(events_addresses_mock)
    end

    context "when the group has an associated address" do
      let(:group_address) { build(:address) }

      it "returns the events' addresses combined with the group's address" do
        expect(group.addresses).to match_array(events_addresses_mock | [ group_address ])
      end
    end

    context "when the group does not have an associated address" do
      let(:group_address) { nil }

      it "returns just the events' addresses" do
        expect(group.addresses).to eq(events_addresses_mock)
      end
    end
  end
end
