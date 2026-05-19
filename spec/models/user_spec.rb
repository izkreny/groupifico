require 'rails_helper'

RSpec.describe User, type: :model do
  describe "(associations)" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_one(:profile).class_name("UserProfile").dependent(:destroy) }
    it { is_expected.to have_many(:members).dependent(:destroy) }
    it { is_expected.to have_many(:groups).through(:members) }
  end

  describe "(validations)" do
    subject { create(:user) }
    it { is_expected.to have_secure_password }
    it { is_expected.to normalize(:email).from(" NAME@XYZ.COM\t\n").to("name@xyz.com") }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_length_of(:email).is_at_most(250) }
    it { is_expected.to allow_values("full.name@top.level.domain", "local@local").for(:email) }
    it { is_expected.to_not allow_values("full.name.top.level.domain", "local").for(:email) }
  end
end
