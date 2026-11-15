require 'rails_helper'

RSpec.describe JoinRequest, type: :model do
  describe "(validations)" do
    it { is_expected.to normalize(:email).from(" NAME@XYZ.COM\t\n").to("name@xyz.com") }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:mobile_phone) }
    it { is_expected.to validate_length_of(:email).is_at_most(250) }
    it { is_expected.to validate_length_of(:first_name).is_at_most(250) }
    it { is_expected.to validate_length_of(:last_name).is_at_most(250) }
    it { is_expected.to validate_length_of(:mobile_phone).is_at_most(50) }

    # WHY: the addresses `User` accepts and refuses, since confirming one this accepts must not fail on `User`'s own validation.
    it { is_expected.to allow_values("Full.Name@some.crazy.domain", "username@local").for(:email) }
    it { is_expected.not_to allow_values("Full.Name.at.another.bizarre.domain", "username").for(:email) }

    it { is_expected.to allow_values("+385 91 123 4567", "(01) 234-5678", "091.123.4567", "0911234567").for(:mobile_phone) }
    it { is_expected.not_to allow_values("call me", "+385 91 abc 4567", "12345", "++385911234567").for(:mobile_phone) }
  end

  describe "(associations)" do
    it { is_expected.to belong_to(:join_link) }

    it "is deleted with the join link it came through" do
      join_request = create(:join_request)

      join_request.join_link.destroy!

      expect(described_class.exists?(join_request.id)).to be false
    end

    it "is deleted when its group regenerates the join link" do
      join_request = create(:join_request)

      JoinLink.mint(join_request.join_link.group)

      expect(described_class.exists?(join_request.id)).to be false
    end
  end
end
