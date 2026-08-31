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
RSpec.describe MemberPolicy, type: :policy do
  # One example per marked cell of the members table in docs/AUTHORIZATION.md, named after the
  # capability rather than the controller action. The three columns the write rows mark are asserted
  # one by one rather than through `can_manage?`, so a change to what that predicate answers fails
  # here rather than passing quietly.
  describe_rule :show? do
    let(:member)  { create(:member) }
    let(:record)  { create(:member, group: member.group) }
    let(:context) { { user: member.user } }

    succeed "for a member holding no role, who may see the member list and each member's details"
  end

  describe_rule :create? do
    let(:group)   { create(:group) }
    let(:actor)   { create(:member, group:) }
    let(:record)  { build(:member, group:) }
    let(:context) { { user: actor.user } }

    failed "for a member holding no role, who may not add a person to the group"

    succeed "for an owner" do
      let(:actor) { create(:member, :owner, group:) }
    end

    succeed "for an administrator" do
      let(:actor) { create(:member, :administrator, group:) }
    end

    succeed "for a members administrator" do
      let(:actor) { create(:member, :members_administrator, group:) }
    end

    failed "for an events administrator, whose column the row leaves blank" do
      let(:actor) { create(:member, :events_administrator, group:) }
    end
  end

  describe_rule :update? do
    let(:group)   { create(:group) }
    let(:actor)   { create(:member, group:) }
    let(:record)  { create(:member, group:) }
    let(:context) { { user: actor.user } }

    failed "for a member holding no role, who may not change another member's status"

    succeed "for an owner" do
      let(:actor) { create(:member, :owner, group:) }
    end

    succeed "for an administrator" do
      let(:actor) { create(:member, :administrator, group:) }
    end

    succeed "for a members administrator" do
      let(:actor) { create(:member, :members_administrator, group:) }
    end

    failed "for an events administrator" do
      let(:actor) { create(:member, :events_administrator, group:) }
    end
  end

  describe_rule :destroy? do
    let(:group)   { create(:group) }
    let(:actor)   { create(:member, group:) }
    let(:record)  { create(:member, group:) }
    let(:context) { { user: actor.user } }

    failed "for a member holding no role, who may not remove a member from the group"

    succeed "for an owner" do
      let(:actor) { create(:member, :owner, group:) }
    end

    succeed "for an administrator" do
      let(:actor) { create(:member, :administrator, group:) }
    end

    succeed "for a members administrator" do
      let(:actor) { create(:member, :members_administrator, group:) }
    end

    failed "for an events administrator" do
      let(:actor) { create(:member, :events_administrator, group:) }
    end
  end

  # Two rows of the table, one rule: granting or revoking a role, and making another member an
  # owner. The owner role is granted the way every other one is, so no mechanism could tell the two
  # decisions apart, and the table gives both to the owner alone.
  describe_rule :manage_roles? do
    let(:group)   { create(:group) }
    let(:actor)   { create(:member, group:) }
    let(:record)  { create(:member, group:) }
    let(:context) { { user: actor.user } }

    failed "for a member holding no role"

    succeed "for an owner" do
      let(:actor) { create(:member, :owner, group:) }
    end

    failed "for an administrator, who may add a member but not grant one a role" do
      let(:actor) { create(:member, :administrator, group:) }
    end

    failed "for a members administrator" do
      let(:actor) { create(:member, :members_administrator, group:) }
    end

    failed "for an events administrator" do
      let(:actor) { create(:member, :events_administrator, group:) }
    end

    # It is in WRITE_RULES, so the status pre-check refuses it before the rule is reached. Without
    # that entry a paused owner would keep the one capability that hands out every other.
    failed "for a paused owner, because granting a role is a write" do
      let(:actor) { create(:member, :paused, :owner, group:) }
    end
  end

  describe "the relation scope" do
    it "excludes members of a group the user has left" do
      user = create(:user)
      gone = create(:member, group: create(:member, :inactive, user:).group)
      kept = create(:member, group: create(:member, :active, user:).group)

      scoped = described_class.new(nil, user:).apply_scope(Member.all, type: :active_record_relation)

      expect(scoped).to include kept
      expect(scoped).not_to include gone
    end
  end
end
