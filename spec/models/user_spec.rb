require 'rails_helper'

RSpec.describe User, type: :model do
  describe "(associations)" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_one(:profile).class_name("UserProfile").dependent(:destroy) }
    it { is_expected.to have_many(:members).dependent(:destroy) }
    it { is_expected.to have_many(:groups).through(:members) }
  end

  describe "(validations)" do
    it { is_expected.to have_secure_password }
    it { is_expected.to normalize(:email).from(" NAME@XYZ.COM\t\n").to("name@xyz.com") }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_length_of(:email).is_at_most(250) }
    it { is_expected.to allow_values("Full.Name@some.crazy.domain", "username@local").for(:email) }
    it { is_expected.not_to allow_values("Full.Name.at.another.bizarre.domain", "username").for(:email) }

    describe "(uniqueness)" do
      subject { create(:user) }

      it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    end
  end

  describe "(profile creation invariant)" do
    it "builds and persists a profile automatically when created" do
      user = create(:user)

      expect(user.profile).to be_a(UserProfile).and be_persisted
    end

    it "cannot be created without a profile" do
      user = build(:user)
      allow(user).to receive(:build_profile)

      expect(user).not_to be_valid
      expect(user.errors[:profile]).to be_present
    end
  end
end
