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
RSpec.describe EventPolicy, type: :policy do
  # One example per marked cell of the events table in docs/AUTHORIZATION.md, named after the
  # capability rather than the controller action. The three role columns are asserted one by one
  # rather than through `can_manage?`, and `manager` is asserted separately because it is not a role
  # at all: it is `events.manager_id`, and it reaches one event.
  describe_rule :show? do
    let(:actor)   { create(:member) }
    let(:record)  { create(:event, group: actor.group) }
    let(:context) { { user: actor.user } }

    succeed "for a member holding no role, who may see the group's events"
  end

  describe_rule :create? do
    let(:group)   { create(:group) }
    let(:actor)   { create(:member, group: group) }
    let(:record)  { build(:event, group: group, creator: actor) }
    let(:context) { { user: actor.user } }

    failed "for a member holding no role, who may not create an event"

    succeed "for an owner" do
      let(:actor) { create(:member, :owner, group: group) }
    end

    succeed "for an administrator" do
      let(:actor) { create(:member, :administrator, group: group) }
    end

    succeed "for an events administrator" do
      let(:actor) { create(:member, :events_administrator, group: group) }
    end

    failed "for a members administrator, whose column the row leaves blank" do
      let(:actor) { create(:member, :members_administrator, group: group) }
    end
  end

  describe_rule :update? do
    let(:group)   { create(:group) }
    let(:actor)   { create(:member, group: group) }
    let(:record)  { create(:event, group: group) }
    let(:context) { { user: actor.user } }

    failed "for a member holding no role, who may not edit an event"

    succeed "for an events administrator" do
      let(:actor) { create(:member, :events_administrator, group: group) }
    end

    succeed "for the event's own manager, who holds no role" do
      let(:record) { create(:event, group: group, manager: actor) }
    end

    failed "for the manager of a different event in the same group" do
      before { create(:event, group: group, manager: actor) }
    end

    # The creator column does not exist: the role that allowed the creation may be gone tomorrow
    # while the record of who made it stays.
    failed "for the event's creator, holding no role" do
      let(:record) { create(:event, group: group, creator: actor) }
    end
  end

  describe_rule :destroy? do
    let(:group)   { create(:group) }
    let(:actor)   { create(:member, group: group) }
    let(:record)  { create(:event, group: group) }
    let(:context) { { user: actor.user } }

    failed "for a member holding no role, who may not delete an event"

    succeed "for an events administrator" do
      let(:actor) { create(:member, :events_administrator, group: group) }
    end

    failed "for the event's own manager, because filling an event is not deleting it" do
      let(:record) { create(:event, group: group, manager: actor) }
    end
  end

  describe_rule :edit? do
    let(:group)   { create(:group) }
    let(:actor)   { create(:member, group: group) }
    let(:record)  { create(:event, group: group) }
    let(:context) { { user: actor.user } }

    failed "for a member holding no role"

    succeed "for an events administrator" do
      let(:actor) { create(:member, :events_administrator, group: group) }
    end

    succeed "for a paused events administrator, because opening the form is a read" do
      let(:actor) { create(:member, :paused, :events_administrator, group: group) }
    end
  end

  describe "the relation scope" do
    it "excludes events of a group the user has left" do
      user = create(:user)
      gone = create(:event, group: create(:member, :inactive, user: user).group)
      kept = create(:event, group: create(:member, :active, user: user).group)

      scoped = described_class.new(nil, user: user).apply_scope(Event.all, type: :active_record_relation)

      expect(scoped).to contain_exactly(kept)
      expect(scoped).not_to include gone
    end
  end
end
