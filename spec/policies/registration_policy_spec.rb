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
RSpec.describe RegistrationPolicy, type: :policy do
  describe "the relation scope" do
    it "excludes registrations on events of a group the user has left" do
      user = create(:user)
      left = create(:member, :inactive, user: user).group
      kept_group = create(:member, :active, user: user).group

      gone = create(:registration, event: create(:event, group: left), member: create(:member, group: left))
      kept = create(:registration, event: create(:event, group: kept_group), member: create(:member, group: kept_group))

      scoped = described_class.new(nil, user: user).apply_scope(Registration.all, type: :active_record_relation)

      expect(scoped).to include kept
      expect(scoped).not_to include gone
    end
  end
end
