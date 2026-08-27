require 'rails_helper'

RSpec.describe AddressPolicy, type: :policy do
  let(:user)    { create(:user) }
  let(:record)  { create(:address) }
  let(:context) { { user: user } }

  describe_rule :show? do
    failed "when no group or event of the user's points at the address"

    succeed "when a group the user belongs to has the address" do
      before { create(:member, user: user, group: create(:group, address: record)) }
    end

    succeed "when an event of a group the user belongs to has the address" do
      before do
        member = create(:member, user: user)
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
      before { create(:member, user: user, group: create(:group, address: record)) }
    end
  end

  # Only `edit?` is an alias now. Opening a form is a read, so it follows show?; submitting is a
  # write, so update? has a body of its own and asks the owners for `update?` rather than `show?`.
  # Action Policy drops an alias the moment a real method of that name is defined - this list has
  # now caught that twice, destroy? and update?, each time the rule stopped delegating.
  describe "rule aliases" do
    subject(:policy) { described_class.new(record, **context) }

    it { expect(:edit?).to be_an_alias_of(policy, :show?) }
  end

  # Inherited from the owner, so the read/write split arrives without this policy asking about
  # membership at all: GroupPolicy refuses a paused member `update?` through the pre-checks, and
  # that refusal is what this rule reads.
  describe_rule :update? do
    failed "when the member of the owning group is paused" do
      before { create(:member, user: user, status: :paused, group: create(:group, address: record)) }
    end

    succeed "when the member of the owning group is active" do
      before { create(:member, user: user, status: :active, group: create(:group, address: record)) }
    end
  end

  # A relation_scope is not a rule, so the pre-checks never run for it - and this policy skips them
  # anyway. `user.groups` is every group ever joined, so an address reachable only through a group
  # the user has left stayed listed.
  describe "the relation scope" do
    it "excludes an address reachable only through a group the user has left" do
      gone = create(:address)
      create(:member, user: user, status: :inactive, group: create(:group, address: gone))

      kept = create(:address)
      create(:member, user: user, status: :active, group: create(:group, address: kept))

      scoped = described_class.new(nil, user: user).apply_scope(Address.all, type: :active_record_relation)

      expect(scoped).to include kept
      expect(scoped).not_to include gone
    end
  end
end
