require 'rails_helper'

RSpec.describe Event, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:creator).class_name("Member").with_foreign_key(:creator_id).inverse_of(:created_events) }
    it { is_expected.to belong_to(:manager).class_name("Member").with_foreign_key(:manager_id).inverse_of(:managed_events).optional }
    it { is_expected.to have_many(:registrations).dependent(:destroy) }
    it { is_expected.to have_many(:attendees).through(:registrations).source(:member) }
    it { is_expected.to belong_to(:address).optional.touch(true) }
    it { is_expected.to accept_nested_attributes_for(:address) }

    describe "nested attributes for address with ':reject_if' option" do
      it "does not build an address if all provided address attributes are empty" do
        event = build(:event, address_attributes: { name: "", city: "" })

        expect(event.address).to be_nil
      end

      it "builds an address if at least one of the provided address attributes is not empty" do
        event = build(:event, address_attributes: { name: "", city: "Ur" })

        expect(event.address).not_to be_nil
      end
    end
  end

  describe "(enums)" do
    it { is_expected.to define_enum_for(:status).with_values(unconfirmed: 0, confirmed: 1, concluded: 2, canceled: 3).with_default(:unconfirmed).validating }
    it { is_expected.to define_enum_for(:category).with_values(other: 0, rehearsal: 1, gig: 2).with_default(:other).validating }
  end

  describe "(validations)" do
    it "is invalid if the address is not valid" do
      valid_event_with_invalid_address = build(:event, address: build(:address, name: ""))

      expect(valid_event_with_invalid_address).to be_invalid
    end

    it "is invalid if the manager is not valid" do
      valid_event_with_invalid_manager = build(:event, manager: build(:member, role: nil))

      expect(valid_event_with_invalid_manager).to be_invalid
    end

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:starts_at) }
    it { is_expected.to validate_presence_of(:ends_at) }
    it { is_expected.to validate_length_of(:name).is_at_most(250) }
    it { is_expected.to validate_length_of(:description).is_at_most(25_000) }

    it "is invalid if the event's end is before its start date and time" do
      invalid_event = build(:event, starts_at: Time.now, ends_at: Time.now - 1.hour)

      expect(invalid_event).to be_invalid
    end
  end

  describe ".upcoming" do
    before do
      create(:event, :from_the_past)
      create(:event, :ongoing)
    end

    context "when there are no events that start in the future" do
      it "returns an empty array" do
        expect(described_class.upcoming).to be_empty
      end
    end

    context "when there are events that start in the future" do
      it "returns all of them" do
        future_event = create(:event, :from_the_future)

        expect(described_class.upcoming).to contain_exactly(future_event)
      end
    end
  end

  describe ".ongoing" do
    before do
      create(:event, :from_the_past)
      create(:event, :from_the_future)
    end

    context "when there are no ongoing events" do
      it "returns an empty array" do
        expect(described_class.ongoing).to be_empty
      end
    end

    context "when there are ongoing events" do
      it "returns all of them" do
        ongoing_event = create(:event, :ongoing)

        expect(described_class.ongoing).to contain_exactly(ongoing_event)
      end
    end
  end

  describe ".past" do
    before do
      create(:event, :ongoing)
      create(:event, :from_the_future)
    end


    context "when there are no events that ended" do
      it "returns an empty array" do
        expect(described_class.past).to be_empty
      end
    end

    context "when there are events that have ended" do
      it "returns all of them" do
        past_event = create(:event, :from_the_past)

        expect(described_class.past).to contain_exactly(past_event)
      end
    end
  end

  describe "#same_day?" do
    context "when the event starts and ends on the same day" do
      it "returns true" do
        same_day_event = build(:event, starts_at: "2012-12-12 12:00:00", ends_at: "2012-12-12 20:00:00")

        expect(same_day_event).to be_same_day
      end
    end

    context "when the event starts and ends on different days" do
      it "returns false" do
        not_same_day_event = build(:event, starts_at: "2011-11-11 11:00:00", ends_at: "2012-12-12 12:00:00")

        expect(not_same_day_event).not_to be_same_day
      end
    end
  end

  describe "#shift_by(duration)" do
    let(:event) { build(:event) }

    context "when the duration is zero" do
     it "returns the event with all attributes unchanged" do
        original_attributes = event.attributes.deep_dup

        expect(event.shift_by(0).attributes).to eq(original_attributes)
      end
    end

    context "when the duration is positive, e.g., 2 hours" do
      it "returns the event with the start and end shifted forward by 2 hours" do
        expect { event.shift_by(2.hours) }
          .to  change(event, :starts_at).by(2.hours)
          .and change(event, :ends_at).by(2.hours)
      end
    end

    context "when the duration is negative, e.g., -2 hours" do
      it "returns the event with the start and end shifted backward by 2 hours" do
        expect { event.shift_by(-2.hours) }
          .to  change(event, :starts_at).by(-2.hours)
          .and change(event, :ends_at).by(-2.hours)
      end
    end

    context "when the duration is not zero" do
     it "returns the event with all attributes unchanged EXCEPT start and end" do
        original_attributes = event.attributes.except("starts_at", "ends_at").deep_dup

        expect(event.shift_by(1.hour).attributes.except("starts_at", "ends_at")).to eq(original_attributes)
      end
    end
  end

  describe "#duplicate" do
    let(:event)            { create(:event, status: :confirmed) }
    let(:duplicated_event) { event.duplicate }

    it "returns an event with duplicated attributes and the default event status" do
      duplicated_attributes           = event.attributes.deep_dup
      duplicated_attributes["status"] = described_class.new.status
      [ "id", "created_at", "updated_at" ].each { duplicated_attributes[it] = nil }

      expect(duplicated_event.attributes).to eq(duplicated_attributes)
    end

    it "returns a new unsaved event" do
      expect(duplicated_event).not_to be_persisted
    end
  end
end
