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
  let(:context) { { user: build_stubbed(:user) } }

  # The two rules that skip the membership pre-checks, so the permitted case is a signed-in user
  # who belongs to nothing - the state the skip exists for, and the one no other spec here reaches.
  # Action Policy's own Defaults module answers `index?` and `create?` false, so each rule below is
  # an override that grants: delete one and the call lands back on that false, which reads as a
  # considered refusal and is not one.
  describe_rule :index? do
    # The class, because that is what `authorize! Group, to: :index?` passes.
    let(:record) { Group }

    succeed "when the user belongs to no group"
  end

  describe_rule :create? do
    let(:record) { Group.new }

    succeed "when the user belongs to no group"
  end

  # `new?` has no rule of its own here, and that is the point: it resolves through Action Policy's
  # inherited alias to `create?`, which is what keeps the form and the submission answering alike.
  # ApplicationPolicy leaves `new?` out of WRITE_RULES on exactly that basis, so a real `new?`
  # method would drop the alias and break the assumption without failing anything else.
  describe "rule aliases" do
    subject(:policy) { described_class.new(Group.new, **context) }

    it { expect(:new?).to be_an_alias_of(policy, :create?) }
  end

  describe "the relation scope" do
    it "excludes a group the user has left" do
      user = create(:user)
      left = create(:member, :inactive, user: user).group
      kept = create(:member, :active, user: user).group

      scoped = described_class.new(nil, user: user).apply_scope(Group.all, type: :active_record_relation)

      expect(scoped).to contain_exactly(kept)
      expect(scoped).not_to include left
    end
  end
end
