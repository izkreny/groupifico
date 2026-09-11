require 'rails_helper'

RSpec.describe Registration, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:member) }
    it { is_expected.to belong_to(:event) }
  end

  describe "(enums)" do
    it { is_expected.to define_enum_for(:status).with_values(reserved: 0, invited: 1, yes: 2, maybe: 3, no: 4).with_default(:reserved).validating }
  end

  describe "#answered?" do
    it "answers true for each of the three answers" do
      Registration::ANSWERS.each do |answer|
        expect(build(:registration, status: answer)).to be_answered
      end
    end

    it "answers false while the registration is reserved or invited" do
      expect(build(:registration, status: :reserved)).not_to be_answered
      expect(build(:registration, status: :invited)).not_to be_answered
    end
  end
end
