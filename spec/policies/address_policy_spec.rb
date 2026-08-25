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

  # Declared aliases rather than rules that repeat show?. Action Policy drops an alias the moment a
  # real method of that name is defined, so the day one of these grows its own body - destroy? is
  # the likely first, once roles land - these examples fail and force it a describe_rule of its own.
  describe "rule aliases" do
    subject(:policy) { described_class.new(record, **context) }

    it { expect(policy.resolve_rule(:edit?)).to eq :show? }
    it { expect(policy.resolve_rule(:update?)).to eq :show? }
    it { expect(policy.resolve_rule(:destroy?)).to eq :show? }
  end
end
