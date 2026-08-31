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
  # One example per marked registration cell of the events table in docs/AUTHORIZATION.md. The split
  # that needs the most care is the manager's: marked for registering somebody, unmarked for
  # changing their answer afterwards and for removing their registration.
  describe_rule :show? do
    let(:actor)   { create(:member) }
    let(:event)   { create(:event, group: actor.group) }
    let(:record)  { create(:registration, event: event, member: create(:member, group: actor.group)) }
    let(:context) { { user: actor.user } }

    succeed "for a member holding no role, who may see who is registered and what they answered"
  end

  describe_rule :create? do
    let(:group)   { create(:group) }
    let(:actor)   { create(:member, group: group) }
    let(:event)   { create(:event, group: group) }
    let(:record)  { build(:registration, event: event, member: create(:member, group: group)) }
    let(:context) { { user: actor.user } }

    failed "for a member holding no role, registering somebody else"

    succeed "for a member registering themselves, whatever roles they hold" do
      let(:record) { build(:registration, event: event, member: actor) }
    end

    succeed "for an owner" do
      let(:actor) { create(:member, :owner, group: group) }
    end

    succeed "for an administrator" do
      let(:actor) { create(:member, :administrator, group: group) }
    end

    succeed "for an events administrator" do
      let(:actor) { create(:member, :events_administrator, group: group) }
    end

    succeed "for the event's manager, which is the invitation row" do
      let(:event) { create(:event, group: group, manager: actor) }
    end

    failed "for a members administrator registering somebody else" do
      let(:actor) { create(:member, :members_administrator, group: group) }
    end
  end

  describe_rule :update? do
    let(:group)   { create(:group) }
    let(:actor)   { create(:member, group: group) }
    let(:event)   { create(:event, group: group) }
    let(:record)  { create(:registration, event: event, member: create(:member, group: group)) }
    let(:context) { { user: actor.user } }

    failed "for a member holding no role, changing another member's answer"

    succeed "for a member changing their own answer" do
      let(:record) { create(:registration, event: event, member: actor) }
    end

    succeed "for an owner" do
      let(:actor) { create(:member, :owner, group: group) }
    end

    succeed "for an administrator" do
      let(:actor) { create(:member, :administrator, group: group) }
    end

    succeed "for an events administrator" do
      let(:actor) { create(:member, :events_administrator, group: group) }
    end

    failed "for the event's manager, who invites and does not overrule" do
      let(:event) { create(:event, group: group, manager: actor) }
    end

    failed "for a members administrator" do
      let(:actor) { create(:member, :members_administrator, group: group) }
    end
  end

  describe_rule :destroy? do
    let(:group)   { create(:group) }
    let(:actor)   { create(:member, group: group) }
    let(:event)   { create(:event, group: group) }
    let(:record)  { create(:registration, event: event, member: create(:member, group: group)) }
    let(:context) { { user: actor.user } }

    failed "for a member holding no role"

    succeed "for an owner" do
      let(:actor) { create(:member, :owner, group: group) }
    end

    succeed "for an administrator" do
      let(:actor) { create(:member, :administrator, group: group) }
    end

    succeed "for an events administrator" do
      let(:actor) { create(:member, :events_administrator, group: group) }
    end

    failed "for the member the registration is for, who answers no instead of withdrawing" do
      let(:record) { create(:registration, event: event, member: actor) }
    end

    failed "for the event's manager" do
      let(:event) { create(:event, group: group, manager: actor) }
    end

    failed "for a members administrator" do
      let(:actor) { create(:member, :members_administrator, group: group) }
    end
  end

  # Which statuses the actor may write, asked by the controller because a posted status is not on
  # the record when update? runs. `reserved` and `invited` are what somebody else puts you into.
  describe_rule :manage_answers? do
    let(:group)   { create(:group) }
    let(:actor)   { create(:member, group: group) }
    let(:event)   { create(:event, group: group) }
    let(:record)  { create(:registration, event: event, member: actor) }
    let(:context) { { user: actor.user } }

    failed "for a member holding no role, even on their own registration"

    succeed "for an events administrator" do
      let(:actor) { create(:member, :events_administrator, group: group) }
    end

    succeed "for the event's manager, who fills the event" do
      let(:event) { create(:event, group: group, manager: actor) }
    end
  end

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
