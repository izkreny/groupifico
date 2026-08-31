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

  # One example per marked cell of the group table in docs/AUTHORIZATION.md. Named after the
  # capability rather than the controller action, so a spec here and a row there can be read against
  # each other; a cell the table leaves blank has a `failed` example and never a missing one.
  describe_rule :show? do
    let(:member)  { create(:member) }
    let(:record)  { member.group }
    let(:context) { { user: member.user } }

    succeed "for a member holding no role, who may see the group and its details"
  end

  describe_rule :update? do
    let(:group)   { create(:group) }
    let(:member)  { create(:member, group: group) }
    let(:record)  { group }
    let(:context) { { user: member.user } }

    failed "for a member holding no role, who may not edit the group's name, type or description"

    succeed "for an owner" do
      let(:member) { create(:member, :owner, group: group) }
    end

    failed "for an administrator, because the row is the owner's alone" do
      let(:member) { create(:member, :administrator, group: group) }
    end

    failed "for a members administrator" do
      let(:member) { create(:member, :members_administrator, group: group) }
    end
  end

  describe_rule :destroy? do
    let(:group)   { create(:group) }
    let(:member)  { create(:member, group: group) }
    let(:record)  { group }
    let(:context) { { user: member.user } }

    failed "for a member holding no role, who may not delete the group"

    succeed "for an owner" do
      let(:member) { create(:member, :owner, group: group) }
    end

    failed "for an administrator, because the row is the owner's alone" do
      let(:member) { create(:member, :administrator, group: group) }
    end
  end

  # `edit?` answers `membership.owner?` under its own name rather than aliasing or composing
  # `update?`, so that opening the form stays a read while submitting it stays a write; the policy
  # carries the account of why both alternatives rename the running rule. Both halves are asserted
  # here: the verdict follows the owner rule, and a paused owner - refused `update?` by the status
  # pre-check - is still admitted to the form.
  describe_rule :edit? do
    let(:group)   { create(:group) }
    let(:member)  { create(:member, group: group) }
    let(:record)  { group }
    let(:context) { { user: member.user } }

    failed "for a member holding no role"

    succeed "for an owner" do
      let(:member) { create(:member, :owner, group: group) }
    end

    failed "for an administrator" do
      let(:member) { create(:member, :administrator, group: group) }
    end

    succeed "for a paused owner, who keeps every read" do
      let(:member) { create(:member, :paused, :owner, group: group) }
    end
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
