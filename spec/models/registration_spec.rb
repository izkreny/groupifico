require 'rails_helper'

RSpec.describe Registration, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:member) }
    it { is_expected.to belong_to(:event) }
  end

  describe "(enums)" do
    it { is_expected.to define_enum_for(:status).with_values(reserved: 0, invited: 1, yes: 2, maybe: 3, no: 4).with_default(:reserved).validating }
  end

  describe ".answer?" do
    # Written out rather than read from `Registration::ANSWERS`, for the reason the sibling below
    # gives: an example iterating the constant agrees with whatever it holds.
    it "answers true for each of the three answers, and for a blank" do
      expect(described_class.answer?("yes")).to be true
      expect(described_class.answer?("maybe")).to be true
      expect(described_class.answer?("no")).to be true
      expect(described_class.answer?(nil)).to be true
    end

    it "answers false for the two statuses somebody else writes" do
      expect(described_class.answer?("reserved")).to be false
      expect(described_class.answer?("invited")).to be false
    end
  end

  describe "#answered?" do
    # The three statuses are written out rather than read from `Registration::ANSWERS`, which is
    # the constant the method asks: an example iterating it agrees with whatever it holds.
    it "answers true for each of the three answers" do
      expect(build(:registration, status: :yes)).to be_answered
      expect(build(:registration, status: :maybe)).to be_answered
      expect(build(:registration, status: :no)).to be_answered
    end

    it "answers false while the registration is reserved or invited" do
      expect(build(:registration, status: :reserved)).not_to be_answered
      expect(build(:registration, status: :invited)).not_to be_answered
    end
  end
end
