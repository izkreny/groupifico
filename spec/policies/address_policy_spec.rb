require 'rails_helper'

RSpec.describe AddressPolicy, type: :policy do
  let(:user)    { create(:user) }
  let(:record)  { create(:address) }
  let(:context) { { user: } }

  describe_rule :show? do
    failed "when no group or event of the user's points at the address"

    succeed "when a group the user belongs to has the address" do
      before { create(:member, user:, group: create(:group, address: record)) }
    end

    succeed "when an event of a group the user belongs to has the address" do
      before do
        member = create(:member, user:)
        create(:event, group: member.group, address: record)
      end
    end

    failed "when the group holding the address is one the user does not belong to" do
      before { create(:group, address: record) }
    end
  end

  # No destroy? rule, and none needed: the route is gone, so there is no action to authorize.
  # Deny-by-default still covers it - ApplicationPolicy inherits `manage?` returning false - which
  # `describe_rule :destroy?` below proves rather than assumes.
  describe_rule :destroy? do
    failed "when a group the user belongs to has the address" do
      before { create(:member, user:, group: create(:group, address: record)) }
    end
  end

  # Only `edit?` is an alias now. An edit form exists only to be submitted, so opening it follows
  # update?, the rule its Save is decided by. Action Policy drops an alias the moment a real method
  # of that name is defined - this list has now caught that twice, destroy? and update?, each time
  # the rule stopped delegating.
  describe "rule aliases" do
    subject(:policy) { described_class.new(record, **context) }

    it { expect(:edit?).to be_an_alias_of(policy, :update?) }
  end

  # Inherited from the owner, so the read/write split arrives without this policy asking about
  # membership at all: GroupPolicy refuses a paused member `update?` through the pre-checks, and
  # that refusal is what this rule reads.
  describe_rule :update? do
    failed "when the member of the owning group is paused" do
      before { create(:member, :paused, :owner, user:, group: create(:group, address: record)) }
    end

    succeed "when the member owns the group the address belongs to" do
      before { create(:member, :active, :owner, user:, group: create(:group, address: record)) }
    end

    # Correcting the group's home address is the same capability as editing the group, so it moved
    # here the moment GroupPolicy#update? did, with nothing in this file changing.
    failed "when the member belongs to the owning group but does not own it" do
      before { create(:member, :active, user:, group: create(:group, address: record)) }
    end

    # The pair that fixes the home address to its group, watched granting the wrong answer before
    # the rule split. The reasoning is `docs/AUTHORIZATION.md`'s and is not repeated here.
    failed "when an events_administrator reaches the group's home address through an event" do
      before do
        group = create(:group, address: record)
        create(:event, group:, address: record)
        create(:member, :active, :events_administrator, user:, group:)
      end
    end

    # The manager is the other column the events table marks, and it is not a role, so it needs its
    # own example rather than following the one above.
    failed "when the event's manager reaches the group's home address through their event" do
      before do
        group  = create(:group, address: record)
        member = create(:member, :active, user:, group:)
        create(:event, group:, address: record, manager: member)
      end
    end

    succeed "when an events_administrator edits an address only an event points at" do
      before do
        member = create(:member, :active, :events_administrator, user:)
        create(:event, group: member.group, address: record)
      end
    end
  end
end
