require 'rails_helper'

# A `relation_scope` is not a rule, so the membership pre-checks never run for it. Every scope on
# this branch asked `user.groups` - every group ever joined - and a member who has gone inactive
# has left, so the list leaked what the detail page refused.
#
# Tested here rather than through the router, deliberately. The nested controllers call
# `authorize! @group` before their `index`, so an inactive member is refused by the group check
# before the scope is ever consulted: a request spec passes with the defect fully restored, which
# was watched happening. That shielding is a property of the callers, not of the scopes, and it
# disappears the moment a second caller arrives.
RSpec.describe GroupPolicy, type: :policy do
  describe "the relation scope" do
    it "excludes a group the user has left" do
      user = create(:user)
      left = create(:member, user: user, status: :inactive).group
      kept = create(:member, user: user, status: :active).group

      scoped = described_class.new(nil, user: user).apply_scope(Group.all, type: :active_record_relation)

      expect(scoped).to contain_exactly(kept)
      expect(scoped).not_to include left
    end
  end
end
