require 'rails_helper'

RSpec.describe Current, type: :model do
  describe ".member" do
    it "answers the acting user's membership of the current group" do
      member = create(:member)
      described_class.session = member.user.sessions.create!
      described_class.group   = member.group

      expect(described_class.member).to eq member
    end

    it "is nil when no group has been set" do
      member = create(:member)
      described_class.session = member.user.sessions.create!

      expect(described_class.member).to be_nil
    end

    it "is nil when no session has been set" do
      member = create(:member)
      described_class.group = member.group

      expect(described_class.member).to be_nil
    end

    # A member of some other group rather than a member of none: an unscoped lookup would find
    # this one and answer with a membership the current group has no claim on.
    it "is nil when the acting user's only membership is in another group" do
      outsider = create(:member)
      described_class.session = outsider.user.sessions.create!
      described_class.group   = create(:group)

      expect(described_class.member).to be_nil
    end
  end
end
