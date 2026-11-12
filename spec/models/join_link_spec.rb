require 'rails_helper'

RSpec.describe JoinLink, type: :model do
  describe "(associations)" do
    it { is_expected.to belong_to(:group) }
  end

  describe ".mint" do
    # WHY: #445 N1, since a database read must leak no live link.
    it "keeps no copy of the token it returns" do
      token = described_class.mint(create(:group))

      expect(described_class.sole.attributes.values.map(&:to_s)).not_to include(token)
    end

    it "carries at least 128 bits of entropy" do
      token = described_class.mint(create(:group))

      expect(Base64.urlsafe_decode64(token).bytesize * 8).to be >= 128
    end

    it "leaves the group one link" do
      group = create(:group)
      described_class.mint(group)

      expect { described_class.mint(group) }.not_to change(described_class, :count)
    end

    it "leaves another group's link alone" do
      other = create(:join_link)

      described_class.mint(create(:group))

      expect(described_class.exists?(other.id)).to be(true)
    end
  end

  describe ".find_by_token" do
    it "finds the link a token was minted for" do
      group = create(:group)
      token = described_class.mint(group)

      expect(described_class.find_by_token(token).group).to eq(group)
    end

    # WHY: #445 AC3, since regenerating is what retires a link that travelled too far.
    it "finds nothing for a token the group has since regenerated" do
      group = create(:group)
      token = described_class.mint(group)
      described_class.mint(group)

      expect(described_class.find_by_token(token)).to be_nil
    end

    # WHY: #445 AC2, since turning the link off is deleting its row.
    it "finds nothing for a token whose link was turned off" do
      group = create(:group)
      token = described_class.mint(group)
      group.join_link.destroy!

      expect(described_class.find_by_token(token)).to be_nil
    end

    it "finds nothing for a token never minted" do
      described_class.mint(create(:group))

      expect(described_class.find_by_token("never-minted")).to be_nil
    end

    it "finds nothing when no token was given, rather than raising" do
      described_class.mint(create(:group))

      expect(described_class.find_by_token(nil)).to be_nil
    end

    it "finds nothing for a token that is not a string, rather than raising" do
      described_class.mint(create(:group))

      expect(described_class.find_by_token([ "malformed" ])).to be_nil
    end
  end
end
