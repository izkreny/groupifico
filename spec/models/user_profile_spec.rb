require 'rails_helper'

RSpec.describe UserProfile, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:user) }
  end

  describe "(validations)" do
    subject { create(:user_profile) }

    it { is_expected.to validate_length_of(:first_name).is_at_most(250) }
    it { is_expected.to validate_length_of(:last_name).is_at_most(250) }
    it { is_expected.to validate_length_of(:mobile_phone).is_at_most(50) }
    it { is_expected.to validate_uniqueness_of(:mobile_phone).case_insensitive.allow_blank }
  end

  describe "#full_name" do
    context "when neither first nor last name is present" do
      it "returns the local-part (username) of the user's email address" do
        user_profile = build(:user_profile, user: build(:user, email: "username@domain"))

        expect(user_profile.full_name).to eq "username"
      end
    end

    context "when the first or last name is present" do
      it "returns the first name if the last name is not present" do
        user_profile = build(:user_profile, first_name: "Nick")

        expect(user_profile.full_name).to eq "Nick"
      end

      it "returns the last name if the first name is not present" do
        user_profile = build(:user_profile, last_name: "Cave")

        expect(user_profile.full_name).to eq "Cave"
      end

      it "returns both first and last names combined when both are present" do
        user_profile = build(:user_profile, first_name: "Nick", last_name: "Cave")

        expect(user_profile.full_name).to eq "Nick Cave"
      end
    end
  end
end
