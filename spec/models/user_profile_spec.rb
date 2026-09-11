require 'rails_helper'

RSpec.describe UserProfile, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:user) }
  end

  describe "(validations)" do
    it { is_expected.to validate_length_of(:first_name).is_at_most(250) }
    it { is_expected.to validate_length_of(:last_name).is_at_most(250) }
    it { is_expected.to validate_length_of(:mobile_phone).is_at_most(50) }
    it { is_expected.to normalize(:mobile_phone).from(" \t\n").to(nil) }

    describe "(uniqeness)" do
      subject { create(:user_profile) }

      it { is_expected.to validate_uniqueness_of(:mobile_phone).case_insensitive.allow_nil }
      it { is_expected.to validate_uniqueness_of(:user_id) }
    end
  end

  describe "#full_name" do
    context "when neither first nor last name is present" do
      it "returns the local-part (username) of the user's email address" do
        user_profile_without_first_and_last_name = build(:user_profile, user: build(:user, email: "username@domain"))

        expect(user_profile_without_first_and_last_name.full_name).to eq "username"
      end
    end

    context "when the first or last name is present" do
      it "returns the first name if the last name is not present" do
        user_profile_with_only_first_name = build(:user_profile, first_name: "Nick")

        expect(user_profile_with_only_first_name.full_name).to eq "Nick"
      end

      it "returns the last name if the first name is not present" do
        user_profile_with_only_last_name = build(:user_profile, last_name: "Cave")

        expect(user_profile_with_only_last_name.full_name).to eq "Cave"
      end

      it "returns both first and last names combined when both are present" do
        user_profile_with_first_and_last_name = build(:user_profile, first_name: "Nick", last_name: "Cave")

        expect(user_profile_with_first_and_last_name.full_name).to eq "Nick Cave"
      end
    end
  end

  describe "#initials" do
    it "takes the first letter of each of both names" do
      expect(build(:user_profile, first_name: "Nick", last_name: "Cave").initials).to eq "NC"
    end

    it "takes one letter when only one name is present" do
      expect(build(:user_profile, first_name: "Nick", last_name: nil).initials).to eq "N"
    end

    # The shell's avatar is the reader's only mark in the header, so a profile with neither name
    # has to show something rather than an empty circle - and it shows the same fallback the name
    # does, which is what makes the two agree.
    it "falls back to the email local-part when neither name is present" do
      nameless = build(:user_profile, first_name: nil, last_name: nil, user: build(:user, email: "username@domain"))

      expect(nameless.initials).to eq "U"
    end

    # `first_name` is one column, so a middle name arrives inside it and the surname is still the
    # last word. Two letters at most, from the ends rather than from the first two words.
    it "takes the outer two letters when a name carries a middle word" do
      expect(build(:user_profile, first_name: "Anna Maria", last_name: "Cave").initials).to eq "AC"
    end

    it "upcases a name typed in lower case" do
      expect(build(:user_profile, first_name: "nick", last_name: "cave").initials).to eq "NC"
    end
  end
end
